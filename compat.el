;;; compat.el --- Compatibility Library              -*- lexical-binding: t; -*-

;; Copyright (C) 2021, 2022 Free Software Foundation, Inc.

;; Author: Philip Kaludercic <philipk@posteo.net>
;; Maintainer: Compat Development <~pkal/compat-devel@lists.sr.ht>
;; Version: 28.1.0.5
;; URL: https://sr.ht/~pkal/compat
;; Package-Requires: ((emacs "24.3") (nadvice "0.3"))
;; Keywords: lisp

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; To allow for the usage of Emacs functions and macros that are
;; defined in newer versions of Emacs, compat.el provides definitions
;; that are installed ONLY if necessary.  These reimplementations of
;; functions and macros are at least subsets of the actual
;; implementations.  Be sure to read the documentation string to make
;; sure.
;;
;; Not every function provided in newer versions of Emacs is provided
;; here.  Some depend on new features from the core, others cannot be
;; implemented to a meaningful degree.  The main audience for this
;; library are not regular users, but package maintainers.  Therefore
;; commands and user options are usually not implemented here.

;;; Code:

(eval-when-compile (require 'compat-macs))

;;;; Core functionality

;; To accelerate the loading process, we insert the contents of
;; compat-N.M.el directly into the compat.elc.  Note that by default
;; this will not include prefix functions.  These have to be required
;; separately, by explicitly requiring the feature that defines them.
(eval-when-compile
  (defvar compat--generate-function)
  (defmacro compat-entwine (version)
    (cond
     ((or (not (eq compat--generate-function 'compat--generate-minimal))
          (bound-and-true-p compat-testing))
      `(load ,(format "compat-%d.el" version)))
     ((let* ((compat--generate-function 'compat--generate-minimal-no-prefix)
             (file (format "compat-%d.el" version))
             defs)
        (with-temp-buffer
          (insert-file-contents file)
          (emacs-lisp-mode)
          (while (progn
                   (forward-comment 1)
                   (not (eobp)))
            (let ((form (read (current-buffer))))
              (when (memq (car-safe form)
                          '(declare-function
                            compat-defun
                            compat-defmacro
                            compat-advise
                            compat-defvar
                            defvar))
                (push form defs)))))
        ;; We bind `byte-compile-current-file' before macro-expanding,
        ;; so that `compat--generate-function' can correctly infer the
        ;; compatibility version currently being processed.
        (let ((byte-compile-current-file file))
          (macroexpand-all
           (macroexp-progn
            (nreverse defs)))))))))

(compat-entwine 24)
(compat-entwine 25)
(compat-entwine 26)
(compat-entwine 27)
(compat-entwine 28)

(provide 'compat)
;;; compat.el ends here
