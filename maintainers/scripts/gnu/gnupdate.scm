;;; GNUpdate -- Update GNU packages in Nixpkgs.     -*- coding: utf-8; -*-
;;; Copyright (C) 2010  Ludovic Courtès <ludo@gnu.org>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(cond-expand (guile-2 #t)
             (else (error "GNU Guile 2.0 is required")))

(use-modules (sxml ssax)
             (ice-9 popen)
             (ice-9 match)
             (ice-9 rdelim)
             (ice-9 regex)
             (ice-9 vlist)
             (srfi srfi-1)
             (srfi srfi-9)
             (srfi srfi-11)
             (srfi srfi-37)
             (system foreign)
             (rnrs bytevectors))


;;;
;;; SNix.
;;;

(define-record-type <location>
  (make-location file line column)
  location?
  (file          location-file)
  (line          location-line)
  (column        location-column))

(define (->loc line column path)
  (and line column path
       (make-location path (string->number line) (string->number column))))

;; XXX: Hack to add missing exports from `(sxml ssax)' as of 1.9.10.
(let ((ssax (resolve-module '(sxml ssax))))
  (for-each (lambda (sym)
              (module-add! (current-module) sym
                           (module-variable ssax sym)))
            '(ssax:warn ssax:skip-pi nl)))

;; Nix object types visible in the XML output of `nix-instantiate' and
;; mapping to S-expressions (we map to sexps, not records, so that we
;; can do pattern matching):
;;
;;   at               (at varpat attrspat)
;;   attr             (attribute loc name value)
;;   attrs            (attribute-set attributes)
;;   attrspat         (attribute-set-pattern patterns)
;;   bool             #f|#t
;;   derivation       (derivation drv-path out-path attributes)
;;   ellipsis         '...
;;   expr             (snix loc body ...)
;;   function         (function loc at|attrspat|varpat)
;;   int              int
;;   list             list
;;   null             'null
;;   path             string
;;   string           string
;;   unevaluated      'unevaluated
;;   varpat           (varpat name)
;;
;; Initially ATTRIBUTES in `derivation' and `attribute-set' was a promise;
;; however, handling `repeated' nodes makes it impossible to do anything
;; lazily because the whole SXML tree has to be traversed to maintain the
;; list of known derivations.

(define (xml-element->snix elem attributes body derivations)
  ;; Return an SNix element corresponding to XML element ELEM.

  (define (loc)
    (->loc (assq-ref attributes 'line)
           (assq-ref attributes 'column)
           (assq-ref attributes 'path)))

  (case elem
    ((at)
     (values `(at ,(car body) ,(cadr body)) derivations))
    ((attr)
     (let ((name (assq-ref attributes 'name)))
       (cond ((null? body)
              (values `(attribute-pattern ,name) derivations))
             ((and (pair? body) (null? (cdr body)))
              (values `(attribute ,(loc) ,name ,(car body))
                      derivations))
             (else
              (error "invalid attribute body" name (loc) body)))))
    ((attrs)
     (values `(attribute-set ,(reverse body)) derivations))
    ((attrspat)
     (values `(attribute-set-pattern ,body) derivations))
    ((bool)
     (values (string-ci=? "true" (assq-ref attributes 'value))
             derivations))
    ((derivation)
     (let ((drv-path (assq-ref attributes 'drvPath))
           (out-path (assq-ref attributes 'outPath)))
       (if (equal? body '(repeated))
           (let ((body (vhash-assoc drv-path derivations)))
             (if (pair? body)
                 (values `(derivation ,drv-path ,out-path ,(cdr body))
                         derivations)
                 (error "no previous occurrence of derivation"
                        drv-path)))
           (values `(derivation ,drv-path ,out-path ,body)
                   (vhash-cons drv-path body derivations)))))
    ((ellipsis)
     (values '... derivations))
    ((expr)
     (values `(snix ,(loc) ,@body) derivations))
    ((function)
     (values `(function ,(loc) ,body) derivations))
    ((int)
     (values (string->number (assq-ref attributes 'value))
             derivations))
    ((list)
     (values body derivations))
    ((null)
     (values 'null derivations))
    ((path)
     (values (assq-ref attributes 'value) derivations))
    ((repeated)
     (values 'repeated derivations))
    ((string)
     (values (assq-ref attributes 'value) derivations))
    ((unevaluated)
     (values 'unevaluated derivations))
    ((varpat)
     (values `(varpat ,(assq-ref attributes 'name)) derivations))
    (else (error "unhandled Nix XML element" elem))))

(define xml->snix
  ;; Return the SNix represention of TREE, an SXML tree as returned by
  ;; parsing the XML output of `nix-instantiate' on Nixpkgs.
  (let ((parse
         (ssax:make-parser NEW-LEVEL-SEED
                           (lambda (elem-gi attributes namespaces expected-content
                                    seed)
                             (cons '() (cdr seed)))

                           FINISH-ELEMENT
                           (lambda (elem-gi attributes namespaces parent-seed
                                            seed)
                             (let ((snix        (car seed))
                                   (derivations (cdr seed)))
                               (let-values (((snix derivations)
                                             (xml-element->snix elem-gi
                                                                attributes
                                                                snix
                                                                derivations)))
                                 (cons (cons snix (car parent-seed))
                                       derivations))))

                           CHAR-DATA-HANDLER
                           (lambda (string1 string2 seed)
                             ;; Discard inter-node strings, which are blanks.
                             seed))))
    (lambda (port)
      ;; Discard the second value returned by the parser (the derivation
      ;; vhash).
      (caar (parse port (cons '() vlist-null))))))

(define (call-with-package snix proc)
  (match snix
    (('attribute _ (and attribute-name (? string?))
                 ('derivation _ _ body))
     ;; Ugly pattern matching.
     (let ((meta
            (any (lambda (attr)
                   (match attr
                     (('attribute _ "meta" ('attribute-set metas)) metas)
                     (_ #f)))
                 body))
           (package-name
            (any (lambda (attr)
                   (match attr
                     (('attribute _ "name" (and name (? string?)))
                      name)
                     (_ #f)))
                 body))
           (location
            (any (lambda (attr)
                   (match attr
                     (('attribute loc "name" (? string?))
                      loc)
                     (_ #f)))
                 body))
           (src
            (any (lambda (attr)
                   (match attr
                     (('attribute _ "src" src)
                      src)
                     (_ #f)))
                 body)))
       (proc attribute-name package-name location meta src)))))

(define (call-with-src snix proc)
  ;; Assume SNIX contains the SNix expression for the value of an `src'
  ;; attribute, as returned by `call-with-package', and call PROC with the
  ;; relevant SRC information, or #f if SNIX doesn't match.
  (match snix
    (('derivation _ _ body)
     (let ((name
            (any (lambda (attr)
                   (match attr
                     (('attribute _ "name" (and name (? string?)))
                      name)
                     (_ #f)))
                 body))
           (output-hash
            (any (lambda (attr)
                   (match attr
                     (('attribute _ "outputHash" (and hash (? string?)))
                      hash)
                     (_ #f)))
                 body))
           (urls
            (any (lambda (attr)
                   (match attr
                     (('attribute _ "urls" (and urls (? pair?)))
                      urls)
                     (_ #f)))
                 body)))
       (proc name output-hash urls)))
    (_ (proc #f #f #f))))

(define (src->values snix)
  (call-with-src snix values))

(define (open-nixpkgs nixpkgs)
  (let ((script  (string-append nixpkgs
                                "/maintainers/scripts/eval-release.nix")))
    (open-pipe* OPEN_READ "nix-instantiate"
                "--strict" "--eval-only" "--xml"
                script)))

(define (nix-prefetch-url url)
  ;; Download URL in the Nix store and return the base32-encoded SHA256 hash
  ;; of the file at URL
  (let* ((pipe (open-pipe* OPEN_READ "nix-prefetch-url" url))
         (hash (read-line pipe)))
    (close-pipe pipe)
    (if (eof-object? hash)
        (values #f #f)
        (let* ((pipe (open-pipe* OPEN_READ "nix-store" "--print-fixed-path"
                                 "sha256" hash (basename url)))
               (path (read-line pipe)))
          (if (eof-object? path)
              (values #f #f)
              (values (string-trim-both hash) (string-trim-both path)))))))

(define (update-nix-expression file
                               old-version old-hash
                               new-version new-hash)
  ;; Modify FILE in-place.  Ugly: we call out to sed(1).
  (let ((cmd (format #f "sed -i \"~a\" -e 's/~A/~a/g ; s/~A/~A/g'"
                     file
                     (regexp-quote old-version) new-version
                     old-hash
                     (or new-hash "new hash not available, check the log"))))
    (format #t "running `~A'...~%" cmd)
    (system cmd)))


;;;
;;; FTP client.
;;;

(define-record-type <ftp-connection>
  (%make-ftp-connection socket addrinfo)
  ftp-connection?
  (socket    ftp-connection-socket)
  (addrinfo  ftp-connection-addrinfo))

(define %ftp-ready-rx
  (make-regexp "^([0-9]{3}) (.+)$"))

(define (%ftp-listen port)
  (let loop ((line (read-line port)))
    (cond ((eof-object? line) (values line #f))
          ((regexp-exec %ftp-ready-rx line)
           =>
           (lambda (match)
             (values (string->number (match:substring match 1))
                     (match:substring match 2))))
          (else
           (loop (read-line port))))))

(define (%ftp-command command expected-code port)
  (format port "~A~A~A" command (string #\return) (string #\newline))
  (let-values (((code message) (%ftp-listen port)))
    (if (eqv? code expected-code)
        message
        (throw 'ftp-error port command code message))))

(define (%ftp-login user pass port)
  (let ((command (string-append "USER " user (string #\newline))))
    (display command port)
    (let-values (((code message) (%ftp-listen port)))
      (case code
        ((230)  #t)
        ((331) (%ftp-command (string-append "PASS " pass) 230 port))
        (else  (throw 'ftp-error port command code message))))))

(define (ftp-open host)
  (catch 'getaddrinfo-error
    (lambda ()
      (let* ((ai (car (getaddrinfo host "ftp")))
             (s  (socket (addrinfo:fam ai) (addrinfo:socktype ai)
                         (addrinfo:protocol ai))))
        (connect s (addrinfo:addr ai))
        (setvbuf s _IOLBF)
        (let-values (((code message) (%ftp-listen s)))
          (if (eqv? code 220)
              (begin
                ;(%ftp-command "OPTS UTF8 ON" 200 s)
                (%ftp-login "anonymous" "ludo@example.com" s)
                (%make-ftp-connection s ai))
              (begin
                (format (current-error-port) "FTP to `~a' failed: ~A: ~A~%"
                        host code message)
                (close s)
                #f)))))
    (lambda (key errcode)
      (format (current-error-port) "failed to resolve `~a': ~a~%"
              host (gai-strerror errcode))
      #f)))

(define (ftp-close conn)
  (close (ftp-connection-socket conn)))

(define (ftp-chdir conn dir)
  (%ftp-command (string-append "CWD " dir) 250
                (ftp-connection-socket conn)))

(define (ftp-pasv conn)
  (define %pasv-rx
    (make-regexp "([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)"))

  (let ((message (%ftp-command "PASV" 227 (ftp-connection-socket conn))))
    (cond ((regexp-exec %pasv-rx message)
           =>
           (lambda (match)
             (+ (* (string->number (match:substring match 5)) 256)
                (string->number (match:substring match 6)))))
          (else
           (throw 'ftp-error conn "PASV" 227 message)))))


(define* (ftp-list conn #:optional directory)
  (define (address-with-port sa port)
    (let ((fam  (sockaddr:fam sa))
          (addr (sockaddr:addr sa)))
      (cond ((= fam AF_INET)
             (make-socket-address fam addr port))
            ((= fam AF_INET6)
             (make-socket-address fam addr port
                                  (sockaddr:flowinfo sa)
                                  (sockaddr:scopeid sa)))
            (else #f))))

  (if directory
      (ftp-chdir conn directory))

  (let* ((port (ftp-pasv conn))
         (ai   (ftp-connection-addrinfo conn))
         (s    (socket (addrinfo:fam ai) (addrinfo:socktype ai)
                       (addrinfo:protocol ai))))
    (connect s (address-with-port (addrinfo:addr ai) port))
    (setvbuf s _IOLBF)

    (dynamic-wind
      (lambda () #t)
      (lambda ()
        (%ftp-command "LIST" 150 (ftp-connection-socket conn))

        (let loop ((line   (read-line s))
                   (result '()))
          (cond ((eof-object? line) (reverse result))
                ((regexp-exec %ftp-ready-rx line)
                 =>
                 (lambda (match)
                   (let ((code (string->number (match:substring match 1))))
                     (if (= 126 code)
                         (reverse result)
                         (throw 'ftp-error conn "LIST" code)))))
                (else
                 (loop (read-line s)
                       (let ((file (car (reverse (string-tokenize line)))))
                         (cons file result)))))))
      (lambda ()
        (close s)
        (let-values (((code message) (%ftp-listen (ftp-connection-socket conn))))
          (or (eqv? code 226)
              (throw 'ftp-error conn "LIST" code message)))))))


;;;
;;; GNU.
;;;

(define %ignored-package-attributes
  ;; Attribute name of packages to be ignored.
  '("bash" "bashReal" "bashInteractive" ;; the full versioned name is incorrect
    "autoconf213"
    "automake17x"
    "automake19x"
    "automake110x"
    "automake" ;; = 1.10.x
    "bison1875"
    "bison23"
    "bison" ;; = 2.3
    "emacs22"
    "emacsSnapshot"
    "gcc295"
    "gcc33"
    "gcc34"
    "gcc40"
    "gcc41"
    "gcc42"
    "gcc43"
    "glibc25"
    "glibc27"
    "glibc29"
    "guile_1_9"
    ))

(define (gnu? package)
  ;; Return true if PACKAGE (a snix expression) is a GNU package (according
  ;; to a simple heuristic.)  Otherwise return #f.
  (match package
    (('attribute _ attribute-name ('derivation _ _ body))
     (any (lambda (attr)
            (match attr
              (('attribute _ "meta" ('attribute-set metas))
               (any (lambda (attr)
                      (match attr
                        (('attribute _ "description" value)
                         (string-prefix? "GNU" value))
                        (('attribute _ "homepage" value)
                         (string-contains value "www.gnu.org"))
                        (_ #f)))
                    metas))
              (_ #f)))
          body))
    (_ #f)))

(define (gnu-packages packages)
  (fold (lambda (package gnu)
          (match package
            (('attribute _ "emacs23Packages" emacs-packages)
             ;; XXX: Should prepend `emacs23Packages.' to attribute names.
             (append (gnu-packages emacs-packages) gnu))
            (('attribute _ attribute-name ('derivation _ _ body))
             (if (member attribute-name %ignored-package-attributes)
                 gnu
                 (if (gnu? package)
                     (cons package gnu)
                     gnu)))
            (_ gnu)))
        '()
        packages))

(define (ftp-server/directory project)
  (define quirks
    '(("commoncpp2"   "ftp.gnu.org"   "/gnu/commoncpp" #f)
      ("libgcrypt"    "ftp.gnupg.org" "/gcrypt" #t)
      ("libgpg-error" "ftp.gnupg.org" "/gcrypt" #t)
      ("gnupg"        "ftp.gnupg.org" "/gcrypt" #t)
      ("gnu-ghostscript" "ftp.gnu.org"  "/ghostscript" #f)
      ("GNUnet"       "ftp.gnu.org" "/gnu/gnunet" #f)
      ("mit-scheme"   "ftp.gnu.org" "/gnu/mit-scheme/stable.pkg")
      ("icecat"       "ftp.gnu.org" "/gnu/gnuzilla" #f)
      ("TeXmacs"      "ftp.texmacs.org" "/TeXmacs/targz" #f)))

  (let ((quirk (assoc project quirks)))
    (match quirk
      ((_ server directory subdir?)
       (values server (if (not subdir?)
                          directory
                          (string-append directory "/" project))))
      (else
       (values "ftp.gnu.org" (string-append "/gnu/" project))))))

(define (nixpkgs->gnu-name project)
  (define quirks
    '(("gcc-wrapper" . "gcc")
      ("ghostscript" . "gnu-ghostscript") ;; ../ghostscript/gnu-ghoscript-X.Y.tar.gz
      ("gnum4"       . "m4")
      ("gnugrep"     . "grep")
      ("gnused"      . "sed")
      ("gnutar"      . "tar")
      ("gnunet"      . "GNUnet") ;; ftp.gnu.org/gnu/gnunet/GNUnet-x.y.tar.gz
      ("mitscheme"   . "mit-scheme")
      ("texmacs"     . "TeXmacs")))

  (or (assoc-ref quirks project) project))

(define (releases project)
  ;; TODO: Handle project release trees like that of IceCat and MyServer.
  (define release-rx
    (make-regexp (string-append "^" project "-[0-9].*\\.tar\\.")))

  (catch #t
    (lambda ()
      (let-values (((server directory) (ftp-server/directory project)))
        (let* ((conn  (ftp-open server))
               (files (ftp-list conn directory)))
          (ftp-close conn)
          (map (lambda (tarball)
                 (let ((end (string-contains tarball ".tar")))
                   (substring tarball 0 end)))

               ;; Filter out signatures, deltas, and files which are potentially
               ;; not releases of PROJECT (e.g., in /gnu/guile, filter out
               ;; guile-oops and guile-www).
               (filter (lambda (file)
                         (and (not (string-suffix? ".sig" file))
                              (regexp-exec release-rx file)))
                       files)))))
    (lambda (key subr message . args)
      (format (current-error-port)
              "failed to get release list for `~A': ~A ~A~%"
              project message args)
      '())))

(define version-string>?
  (let ((strverscmp
         (let ((sym (or (dynamic-func "strverscmp" (dynamic-link))
                        (error "could not find `strverscmp' (from GNU libc)"))))
           (make-foreign-function int sym (list '* '*))))
        (string->null-terminated-utf8
         (lambda (s)
           (let* ((utf8 (string->utf8 s))
                  (len  (bytevector-length utf8))
                  (nts  (make-bytevector (+ len 1))))
             (bytevector-copy! utf8 0 nts 0 len)
             (bytevector-u8-set! nts len 0)
             nts))))
    (lambda (a b)
      (let ((a (bytevector->foreign (string->null-terminated-utf8 a)))
            (b (bytevector->foreign (string->null-terminated-utf8 b))))
        (> (strverscmp a b) 0)))))

(define (latest-release project)
  ;; Return "FOO-X.Y" or #f.
  (let ((releases (releases project)))
    (and (not (null? releases))
         (fold (lambda (release latest)
                 (if (version-string>? release latest)
                     release
                     latest))
               ""
               releases))))

(define (package/version name+version)
  (let ((hyphen (string-rindex name+version #\-)))
    (if (not hyphen)
        (values name+version #f)
        (let ((name    (substring name+version 0 hyphen))
              (version (substring name+version (+ hyphen 1)
                                  (string-length name+version))))
          (values name version)))))

(define (file-extension file)
  (let ((dot (string-rindex file #\.)))
    (and dot (substring file (+ 1 dot) (string-length file)))))

(define (packages-to-update gnu-packages)
  (fold (lambda (pkg result)
          (call-with-package pkg
            (lambda (attribute name+version location meta src)
              (let-values (((name old-version)
                            (package/version name+version)))
                (let ((latest (latest-release (nixpkgs->gnu-name name))))
                  (cond ((not latest)
                         (format #t "~A [unknown latest version]~%"
                                 name+version)
                         result)
                        ((string=? name+version latest)
                         (format #t "~A [up to date]~%" name+version)
                         result)
                        (else
                         (let-values (((project new-version)
                                       (package/version latest))
                                      ((old-name old-hash old-urls)
                                       (src->values src)))
                           (format #t "~A -> ~A [~A]~%" name+version latest
                                   (and (pair? old-urls) (car old-urls)))
                           (let* ((url      (and (pair? old-urls)
                                                 (car old-urls)))
                                  (new-hash (fetch-gnu project new-version
                                                       (if url
                                                           (file-extension url)
                                                           "gz"))))
                             (cons (list name attribute
                                         old-version old-hash
                                         new-version new-hash
                                         location)
                                   result))))))))))
        '()
        gnu-packages))

(define (fetch-gnu project version archive-type)
  (let-values (((server directory)
                (ftp-server/directory project)))
    (let* ((base    (string-append project "-" version ".tar." archive-type))
           (url     (string-append "ftp://" server "/" directory "/" base))
           (sig     (string-append base ".sig"))
           (sig-url (string-append url ".sig")))
      (let-values (((hash path) (nix-prefetch-url url)))
        (pk 'prefetch-url url hash path)
        (and hash path
             (begin
               (false-if-exception (delete-file sig))
               (system* "wget" sig-url)
               (if (file-exists? sig)
                   (let ((ret (system* "gpg" "--verify" sig path)))
                     (false-if-exception (delete-file sig))
                     (if (and ret (= 0 (status:exit-val ret)))
                         hash
                         (begin
                           (format (current-error-port)
                                   "signature verification failed for `~a'~%"
                                   base)
                           (format (current-error-port)
                                   "(could be because the public key is not in your keyring)~%")
                           #f)))
                   (begin
                     (format (current-error-port)
                             "no signature for `~a'~%" base)
                     hash))))))))


;;;
;;; Main program.
;;;

(define %options
  ;; Specifications of the command-line options.
  (list (option '(#\h "help") #f #f
                (lambda (opt name arg result)
                  (format #t "Usage: gnupdate [OPTIONS...]~%")
                  (format #t "GNUpdate -- update Nix expressions of GNU packages in Nixpkgs~%")
                  (format #t "~%")
                  (format #t "  -x, --xml=FILE      Read XML output of `nix-instantiate'~%")
                  (format #t "                      from FILE.~%")
                  (format #t "  -d, --dry-run       Don't actually update Nix expressions~%")
                  (format #t "  -h, --help          Give this help list.~%~%")
                  (format #t "Report bugs to <ludo@gnu.org>~%")
                  (exit 0)))
        (option '(#\d "dry-run") #f #f
                (lambda (opt name arg result)
                  (alist-cons 'dry-run #t result)))

        (option '(#\x "xml") #t #f
                (lambda (opt name arg result)
                  (alist-cons 'xml-file arg result)))))

(define-public (main . args)
  ;; Assume Nixpkgs is under $NIXPKGS or ~/src/nixpkgs.
  (let* ((opts      (args-fold args %options
                               (lambda (opt name arg result)
                                 (error "unrecognized option `~A'" name))
                               (lambda (operand result)
                                 (error "extraneous argument `~A'" operand))
                               '()))
         (home      (getenv "HOME"))
         (path      (or (getenv "NIXPKGS")
                        (string-append home "/src/nixpkgs")))
         (snix      (begin
                      (format (current-error-port) "parsing XML...~%")
                      (xml->snix
                       (or (and=> (assoc-ref opts 'xml-file) open-input-file)
                           (open-nixpkgs path)))))
         (packages  (match snix
                      (('snix _ ('attribute-set attributes))
                       attributes)
                      (else #f)))
         (gnu       (gnu-packages packages))
         (updates   (packages-to-update gnu)))
    (format #t "~%~A packages to update...~%" (length updates))
    (for-each (lambda (update)
                (match update
                  ((name attribute
                    old-version old-hash
                    new-version new-hash
                    location)
                   (if (assoc-ref opts 'dry-run)
                       (format #t "`~a' would be updated from ~a to ~a (~a -> ~a)~%"
                               name old-version new-version
                               old-hash new-hash)
                       (update-nix-expression (location-file location)
                                              old-version old-hash
                                              new-version new-hash)))
                  (_ #f)))
              updates)
    #t))
