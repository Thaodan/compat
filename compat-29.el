;;; compat-29.el --- Compatibility Layer for Emacs 29.1  -*- lexical-binding: t; -*-

;; Copyright (C) 2021, 2022 Free Software Foundation, Inc.

;; Author: Philip Kaludercic <philipk@posteo.net>
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

;; Find here the functionality added in Emacs 29.1, needed by older
;; versions.
;;
;; Only load this library if you need to use one of the following
;; functions:
;;
;; - `plist-get'
;; - `plist-put'
;; - `plist-member'
;; - `define-key'

;;; Code:

(eval-when-compile (require 'compat-macs))

(compat-declare-version "29.1")

;;;; Defined in xdisp.c

(compat-defun get-display-property (position prop &optional object properties)
  "Get the value of the `display' property PROP at POSITION.
If OBJECT, this should be a buffer or string where the property is
fetched from.  If omitted, OBJECT defaults to the current buffer.

If PROPERTIES, look for value of PROP in PROPERTIES instead of
the properties at POSITION."
  (if properties
      (unless (listp properties)
        (signal 'wrong-type-argument (list 'listp properties)))
    (setq properties (get-text-property position 'display object)))
  (cond
   ((vectorp properties)
    (catch 'found
      (dotimes (i (length properties))
        (let ((ent (aref properties i)))
          (when (eq (car ent) prop)
            (throw 'found (cadr ent )))))))
   ((consp (car properties))
    (condition-case nil
        (cadr (assq prop properties))
      ;; Silently handle improper lists:
      (wrong-type-argument nil)))
   ((and (consp (cdr properties))
         (eq (car properties) prop))
    (cadr properties))))

;;* UNTESTED
(compat-defun buffer-text-pixel-size
    (&optional buffer-or-name window x-limit y-limit)
  "Return size of whole text of BUFFER-OR-NAME in WINDOW.
BUFFER-OR-NAME must specify a live buffer or the name of a live buffer
and defaults to the current buffer.  WINDOW must be a live window and
defaults to the selected one.  The return value is a cons of the maximum
pixel-width of any text line and the pixel-height of all the text lines
of the buffer specified by BUFFER-OR-NAME.

The optional arguments X-LIMIT and Y-LIMIT have the same meaning as with
`window-text-pixel-size'.

Do not use this function if the buffer specified by BUFFER-OR-NAME is
already displayed in WINDOW.  `window-text-pixel-size' is cheaper in
that case because it does not have to temporarily show that buffer in
WINDOW."
  :realname compat--buffer-text-pixel-size
  (setq buffer-or-name (or buffer-or-name (current-buffer)))
  (setq window (or window (selected-window)))
  (save-window-excursion
    (set-window-buffer window buffer-or-name)
    (window-text-pixel-size window nil nil x-limit y-limit)))

;;;; Defined in fns.c

(compat-defun ntake (n list)
  "Modify LIST to keep only the first N elements.
If N is zero or negative, return nil.
If N is greater or equal to the length of LIST, return LIST unmodified.
Otherwise, return LIST after truncating it."
  :realname compat--ntake-elisp
  (and (> n 0) (let ((cons (nthcdr (1- n) list)))
                 (when cons (setcdr cons nil))
                 list)))

(compat-defun take (n list)
  "Return the first N elements of LIST.
If N is zero or negative, return nil.
If N is greater or equal to the length of LIST, return LIST (or a copy)."
  (let (copy)
    (while (and (< 0 n) list)
      (push (pop list) copy)
      (setq n (1- n)))
    (nreverse copy)))

(compat-defun string-equal-ignore-case (string1 string2)
  "Like `string-equal', but case-insensitive.
Upper-case and lower-case letters are treated as equal.
Unibyte strings are converted to multibyte for comparison."
  (declare (pure t) (side-effect-free t))
  (eq t (compare-strings string1 0 nil string2 0 nil t)))

(compat-defun plist-get (plist prop &optional predicate)
  "Extract a value from a property list.
PLIST is a property list, which is a list of the form
\(PROP1 VALUE1 PROP2 VALUE2...).

This function returns the value corresponding to the given PROP, or
nil if PROP is not one of the properties on the list.  The comparison
with PROP is done using PREDICATE, which defaults to `eq'.

This function doesn't signal an error if PLIST is invalid."
  :prefix t
  (if (or (null predicate) (eq predicate 'eq))
      (plist-get plist prop)
    (catch 'found
      (while (consp plist)
        (when (funcall predicate prop (car plist))
          (throw 'found (cadr plist)))
        (setq plist (cddr plist))))))

(compat-defun plist-put (plist prop val &optional predicate)
  "Change value in PLIST of PROP to VAL.
PLIST is a property list, which is a list of the form
\(PROP1 VALUE1 PROP2 VALUE2 ...).

The comparison with PROP is done using PREDICATE, which defaults to `eq'.

If PROP is already a property on the list, its value is set to VAL,
otherwise the new PROP VAL pair is added.  The new plist is returned;
use `(setq x (plist-put x prop val))' to be sure to use the new value.
The PLIST is modified by side effects."
  :prefix t
  (if (or (null predicate) (eq predicate 'eq))
      (plist-put plist prop val)
    (catch 'found
      (let ((tail plist))
        (while (consp tail)
          (when (funcall predicate prop (car tail))
            (setcar (cdr tail) val)
            (throw 'found plist))
          (setq tail (cddr tail))))
      (nconc plist (list prop val)))))

(compat-defun plist-member (plist prop &optional predicate)
  "Return non-nil if PLIST has the property PROP.
PLIST is a property list, which is a list of the form
\(PROP1 VALUE1 PROP2 VALUE2 ...).

The comparison with PROP is done using PREDICATE, which defaults to
`eq'.

Unlike `plist-get', this allows you to distinguish between a missing
property and a property with the value nil.
The value is actually the tail of PLIST whose car is PROP."
  :prefix t
  (if (or (null predicate) (eq predicate 'eq))
      (plist-member plist prop)
    (catch 'found
      (while (consp plist)
        (when (funcall predicate prop (car plist))
          (throw 'found plist))
        (setq plist (cddr plist))))))

;;;; Defined in keymap.c

(compat-defun define-key (keymap key def &optional remove)
  "In KEYMAP, define key sequence KEY as DEF.
This is a legacy function; see `keymap-set' for the recommended
function to use instead.

KEYMAP is a keymap.

KEY is a string or a vector of symbols and characters, representing a
sequence of keystrokes and events.  Non-ASCII characters with codes
above 127 (such as ISO Latin-1) can be represented by vectors.
Two types of vector have special meanings:
 [remap COMMAND] remaps any key binding for COMMAND.
 [t] creates a default definition, which applies to any event with no
    other definition in KEYMAP.

DEF is anything that can be a key's definition:
 nil (means key is undefined in this keymap),
 a command (a Lisp function suitable for interactive calling),
 a string (treated as a keyboard macro),
 a keymap (to define a prefix key),
 a symbol (when the key is looked up, the symbol will stand for its
    function definition, which should at that time be one of the above,
    or another symbol whose function definition is used, etc.),
 a cons (STRING . DEFN), meaning that DEFN is the definition
    (DEFN should be a valid definition in its own right) and
    STRING is the menu item name (which is used only if the containing
    keymap has been created with a menu name, see `make-keymap'),
 or a cons (MAP . CHAR), meaning use definition of CHAR in keymap MAP,
 or an extended menu item definition.
 (See info node `(elisp)Extended Menu Items'.)

If REMOVE is non-nil, the definition will be removed.  This is almost
the same as setting the definition to nil, but makes a difference if
the KEYMAP has a parent, and KEY is shadowing the same binding in the
parent.  With REMOVE, subsequent lookups will return the binding in
the parent, and with a nil DEF, the lookups will return nil.

If KEYMAP is a sparse keymap with a binding for KEY, the existing
binding is altered.  If there is no binding for KEY, the new pair
binding KEY to DEF is added at the front of KEYMAP."
  :realname compat--define-key-with-remove
  :prefix t
  (if remove
      (let ((prev (lookup-key keymap key))
            (parent (memq 'key (cdr keymap)))
            fresh entry)
        (when prev
          ;; IMPROVEME: Kind of a hack to avoid relying on the specific
          ;; behaviour of how `define-key' changes KEY before inserting
          ;; it into the map.
          (define-key keymap key (setq fresh (make-symbol "fresh")))
          (setq entry (rassq fresh (cdr keymap)))
          (if (> (length (memq entry (cdr keymap)))
                 (length parent))
              ;; Ensure that we only remove an element in the current
              ;; keymap and not a parent, by ensuring that `entry' is
              ;; located before `parent'.
              (ignore (setcdr keymap (delq entry (cdr keymap))))
            (define-key keymap key prev))))
    (define-key keymap key def)))

;;;; Defined in subr.el

(compat-defun function-alias-p (func &optional noerror)
  "Return nil if FUNC is not a function alias.
If FUNC is a function alias, return the function alias chain.

If the function alias chain contains loops, an error will be
signalled.  If NOERROR, the non-loop parts of the chain is returned."
  (declare (side-effect-free t))
  (let ((chain nil)
        (orig-func func))
    (nreverse
     (catch 'loop
       (while (and (symbolp func)
                   (setq func (symbol-function func))
                   (symbolp func))
         (when (or (memq func chain)
                   (eq func orig-func))
           (if noerror
               (throw 'loop chain)
             (signal 'cyclic-function-indirection (list orig-func))))
         (push func chain))
       chain))))

(declare-function compat--provided-mode-derived-p
                  "compat-27" (mode &rest modes))
(declare-function compat--func-arity
                  "compat-26" (func))

;;* UNTESTED
(compat-defun buffer-match-p (condition buffer-or-name &optional arg)
  "Return non-nil if BUFFER-OR-NAME matches CONDITION.
CONDITION is either:
- the symbol t, to always match,
- the symbol nil, which never matches,
- a regular expression, to match a buffer name,
- a predicate function that takes a buffer object and ARG as
  arguments, and returns non-nil if the buffer matches,
- a cons-cell, where the car describes how to interpret the cdr.
  The car can be one of the following:
  * `derived-mode': the buffer matches if the buffer's major mode
    is derived from the major mode in the cons-cell's cdr.
  * `major-mode': the buffer matches if the buffer's major mode
    is eq to the cons-cell's cdr.  Prefer using `derived-mode'
    instead when both can work.
  * `not': the cdr is interpreted as a negation of a condition.
  * `and': the cdr is a list of recursive conditions, that all have
    to be met.
  * `or': the cdr is a list of recursive condition, of which at
    least one has to be met."
  :realname compat--buffer-match-p
  (letrec
      ((buffer (get-buffer buffer-or-name))
       (match
        (lambda (conditions)
          (catch 'match
            (dolist (condition conditions)
              (when (cond
                     ((eq condition t))
                     ((stringp condition)
                      (string-match-p condition (buffer-name buffer)))
                     ((functionp condition)
                      (if (eq 1 (cdr (compat--func-arity condition)))
                          (funcall condition buffer)
                        (funcall condition buffer arg)))
                     ((eq (car-safe condition) 'major-mode)
                      (eq
                       (buffer-local-value 'major-mode buffer)
                       (cdr condition)))
                     ((eq (car-safe condition) 'derived-mode)
                      (compat--provided-mode-derived-p
                       (buffer-local-value 'major-mode buffer)
                       (cdr condition)))
                     ((eq (car-safe condition) 'not)
                      (not (funcall match (cdr condition))))
                     ((eq (car-safe condition) 'or)
                      (funcall match (cdr condition)))
                     ((eq (car-safe condition) 'and)
                      (catch 'fail
                        (dolist (c (cdr conditions))
                          (unless (funcall match c)
                            (throw 'fail nil)))
                        t)))
                (throw 'match t)))))))
    (funcall match (list condition))))

;;* UNTESTED
(compat-defun match-buffers (condition &optional buffers arg)
  "Return a list of buffers that match CONDITION.
See `buffer-match' for details on CONDITION.  By default all
buffers are checked, this can be restricted by passing an
optional argument BUFFERS, set to a list of buffers to check.
ARG is passed to `buffer-match', for predicate conditions in
CONDITION."
  (let (bufs)
    (dolist (buf (or buffers (buffer-list)))
      (when (compat--buffer-match-p condition (get-buffer buf) arg)
        (push buf bufs)))
    bufs))

;;;; Defined in subr-x.el

(compat-defun string-limit (string length &optional end coding-system)
  "Return a substring of STRING that is (up to) LENGTH characters long.
If STRING is shorter than or equal to LENGTH characters, return the
entire string unchanged.

If STRING is longer than LENGTH characters, return a substring
consisting of the first LENGTH characters of STRING.  If END is
non-nil, return the last LENGTH characters instead.

If CODING-SYSTEM is non-nil, STRING will be encoded before
limiting, and LENGTH is interpreted as the number of bytes to
limit the string to.  The result will be a unibyte string that is
shorter than LENGTH, but will not contain \"partial\" characters,
even if CODING-SYSTEM encodes characters with several bytes per
character.

When shortening strings for display purposes,
`truncate-string-to-width' is almost always a better alternative
than this function."
  :feature 'subr-x
  (unless (natnump length)
    (signal 'wrong-type-argument (list 'natnump length)))
  (if coding-system
      (let ((result nil)
            (result-length 0)
            (index (if end (1- (length string)) 0)))
        (while (let ((encoded (encode-coding-char
                               (aref string index) coding-system)))
                 (and (<= (+ (length encoded) result-length) length)
                      (progn
                        (push encoded result)
                        (setq result-length
                              (+ result-length (length encoded)))
                        (setq index (if end (1- index)
                                      (1+ index))))
                      (if end (> index -1)
                        (< index (length string)))))
          ;; No body.
          )
        (apply #'concat (if end result (nreverse result))))
    (cond
     ((<= (length string) length) string)
     (end (substring string (- (length string) length)))
     (t (substring string 0 length)))))

;;* UNTESTED
(compat-defun string-pixel-width (string)
  "Return the width of STRING in pixels."
  :feature 'subr-x
  (if (zerop (length string))
      0
    ;; Keeping a work buffer around is more efficient than creating a
    ;; new temporary buffer.
    (with-current-buffer (get-buffer-create " *string-pixel-width*")
      (delete-region (point-min) (point-max))
      (insert string)
      (car (compat--buffer-text-pixel-size nil nil t)))))

;;* UNTESTED
(compat-defmacro with-buffer-unmodified-if-unchanged (&rest body)
  "Like `progn', but change buffer-modified status only if buffer text changes.
If the buffer was unmodified before execution of BODY, and
buffer text after execution of BODY is identical to what it was
before, ensure that buffer is still marked unmodified afterwards.
For example, the following won't change the buffer's modification
status:

  (with-buffer-unmodified-if-unchanged
    (insert \"a\")
    (delete-char -1))

Note that only changes in the raw byte sequence of the buffer text,
as stored in the internal representation, are monitored for the
purpose of detecting the lack of changes in buffer text.  Any other
changes that are normally perceived as \"buffer modifications\", such
as changes in text properties, `buffer-file-coding-system', buffer
multibyteness, etc. -- will not be noticed, and the buffer will still
be marked unmodified, effectively ignoring those changes."
  :feature 'subr-x
  (declare (debug t) (indent 0))
  (let ((hash (make-symbol "hash"))
        (buffer (make-symbol "buffer")))
    `(let ((,hash (and (not (buffer-modified-p))
                       (buffer-hash)))
           (,buffer (current-buffer)))
       (prog1
           (progn
             ,@body)
         ;; If we didn't change anything in the buffer (and the buffer
         ;; was previously unmodified), then flip the modification status
         ;; back to "unchanged".
         (when (and ,hash (buffer-live-p ,buffer))
           (with-current-buffer ,buffer
             (when (and (buffer-modified-p)
                        (equal ,hash (buffer-hash)))
               (restore-buffer-modified-p nil))))))))

;;* UNTESTED
(compat-defun add-display-text-property (start end prop value
                                               &optional object)
  "Add display property PROP with VALUE to the text from START to END.
If any text in the region has a non-nil `display' property, those
properties are retained.

If OBJECT is non-nil, it should be a string or a buffer.  If nil,
this defaults to the current buffer."
  :feature 'subr-x
  (let ((sub-start start)
        (sub-end 0)
        disp)
    (while (< sub-end end)
      (setq sub-end (next-single-property-change sub-start 'display object
                                                 (if (stringp object)
                                                     (min (length object) end)
                                                   (min end (point-max)))))
      (if (not (setq disp (get-text-property sub-start 'display object)))
          ;; No old properties in this range.
          (put-text-property sub-start sub-end 'display (list prop value))
        ;; We have old properties.
        (let ((vector nil))
          ;; Make disp into a list.
          (setq disp
                (cond
                 ((vectorp disp)
                  (setq vector t)
                  (append disp nil))
                 ((not (consp (car disp)))
                  (list disp))
                 (t
                  disp)))
          ;; Remove any old instances.
          (let ((old (assoc prop disp)))
            (when old (setq disp (delete old disp))))
          (setq disp (cons (list prop value) disp))
          (when vector
            (setq disp (vconcat disp)))
          ;; Finally update the range.
          (put-text-property sub-start sub-end 'display disp)))
      (setq sub-start sub-end))))

;;;; Defined in files.el

(compat-defun file-parent-directory (filename)
  "Return the directory name of the parent directory of FILENAME.
If FILENAME is at the root of the filesystem, return nil.
If FILENAME is relative, it is interpreted to be relative
to `default-directory', and the result will also be relative."
  (let* ((expanded-filename (expand-file-name filename))
         (parent (file-name-directory (directory-file-name expanded-filename))))
    (cond
     ;; filename is at top-level, therefore no parent
     ((or (null parent)
          (file-equal-p parent expanded-filename))
      nil)
     ;; filename is relative, return relative parent
     ((not (file-name-absolute-p filename))
      (file-relative-name parent))
     (t
      parent))))

(defvar compat--file-has-changed-p--hash-table (make-hash-table :test #'equal)
  "Internal variable used by `file-has-changed-p'.")

;;* UNTESTED
(compat-defun file-has-changed-p (file &optional tag)
  "Return non-nil if FILE has changed.
The size and modification time of FILE are compared to the size
and modification time of the same FILE during a previous
invocation of `file-has-changed-p'.  Thus, the first invocation
of `file-has-changed-p' always returns non-nil when FILE exists.
The optional argument TAG, which must be a symbol, can be used to
limit the comparison to invocations with identical tags; it can be
the symbol of the calling function, for example."
  (let* ((file (directory-file-name (expand-file-name file)))
         (remote-file-name-inhibit-cache t)
         (fileattr (file-attributes file 'integer))
	 (attr (and fileattr
                    (cons (nth 7 fileattr)
		          (nth 5 fileattr))))
	 (sym (concat (symbol-name tag) "@" file))
	 (cachedattr (gethash sym compat--file-has-changed-p--hash-table)))
     (when (not (equal attr cachedattr))
       (puthash sym attr compat--file-has-changed-p--hash-table))))

;;;; Defined in keymap.el

(compat-defun key-valid-p (keys)
  "Say whether KEYS is a valid key.
A key is a string consisting of one or more key strokes.
The key strokes are separated by single space characters.

Each key stroke is either a single character, or the name of an
event, surrounded by angle brackets.  In addition, any key stroke
may be preceded by one or more modifier keys.  Finally, a limited
number of characters have a special shorthand syntax.

Here's some example key sequences.

  \"f\"           (the key `f')
  \"S o m\"       (a three key sequence of the keys `S', `o' and `m')
  \"C-c o\"       (a two key sequence of the keys `c' with the control modifier
                 and then the key `o')
  \"H-<left>\"    (the key named \"left\" with the hyper modifier)
  \"M-RET\"       (the \"return\" key with a meta modifier)
  \"C-M-<space>\" (the \"space\" key with both the control and meta modifiers)

These are the characters that have shorthand syntax:
NUL, RET, TAB, LFD, ESC, SPC, DEL.

Modifiers have to be specified in this order:

   A-C-H-M-S-s

which is

   Alt-Control-Hyper-Meta-Shift-super"
  :realname compat--key-valid-p
  (declare (pure t) (side-effect-free t))
  (let ((case-fold-search nil))
    (and
     (stringp keys)
     (string-match-p "\\`[^ ]+\\( [^ ]+\\)*\\'" keys)
     (save-match-data
       (catch 'exit
         (let ((prefixes
                "\\(A-\\)?\\(C-\\)?\\(H-\\)?\\(M-\\)?\\(S-\\)?\\(s-\\)?"))
           (dolist (key (split-string keys " "))
             ;; Every key might have these modifiers, and they should be
             ;; in this order.
             (when (string-match (concat "\\`" prefixes) key)
               (setq key (substring key (match-end 0))))
             (unless (or (and (= (length key) 1)
                              ;; Don't accept control characters as keys.
                              (not (< (aref key 0) ?\s))
                              ;; Don't accept Meta'd characters as keys.
                              (or (multibyte-string-p key)
                                  (not (<= 127 (aref key 0) 255))))
                         (and (string-match-p "\\`<[-_A-Za-z0-9]+>\\'" key)
                              ;; Don't allow <M-C-down>.
                              (= (progn
                                   (string-match
                                    (concat "\\`<" prefixes) key)
                                   (match-end 0))
                                 1))
                         (string-match-p
                          "\\`\\(NUL\\|RET\\|TAB\\|LFD\\|ESC\\|SPC\\|DEL\\)\\'"
                          key))
               ;; Invalid.
               (throw 'exit nil)))
           t))))))

(compat-defun key-parse (keys)
  "Convert KEYS to the internal Emacs key representation.
See `kbd' for a descripion of KEYS."
  :realname compat--key-parse
  (declare (pure t) (side-effect-free t))
  ;; A pure function is expected to preserve the match data.
  (save-match-data
    (let ((case-fold-search nil)
          (len (length keys)) ; We won't alter keys in the loop below.
          (pos 0)
          (res []))
      (while (and (< pos len)
                  (string-match "[^ \t\n\f]+" keys pos))
        (let* ((word-beg (match-beginning 0))
               (word-end (match-end 0))
               (word (substring keys word-beg len))
               (times 1)
               key)
          ;; Try to catch events of the form "<as df>".
          (if (string-match "\\`<[^ <>\t\n\f][^>\t\n\f]*>" word)
              (setq word (match-string 0 word)
                    pos (+ word-beg (match-end 0)))
            (setq word (substring keys word-beg word-end)
                  pos word-end))
          (when (string-match "\\([0-9]+\\)\\*." word)
            (setq times (string-to-number (substring word 0 (match-end 1))))
            (setq word (substring word (1+ (match-end 1)))))
          (cond ((string-match "^<<.+>>$" word)
                 (setq key (vconcat (if (eq (key-binding [?\M-x])
                                            'execute-extended-command)
                                        [?\M-x]
                                      (or (car (where-is-internal
                                                'execute-extended-command))
                                          [?\M-x]))
                                    (substring word 2 -2) "\r")))
                ((and (string-match "^\\(\\([ACHMsS]-\\)*\\)<\\(.+\\)>$" word)
                      (progn
                        (setq word (concat (match-string 1 word)
                                           (match-string 3 word)))
                        (not (string-match
                              "\\<\\(NUL\\|RET\\|LFD\\|ESC\\|SPC\\|DEL\\)$"
                              word))))
                 (setq key (list (intern word))))
                ((or (equal word "REM") (string-match "^;;" word))
                 (setq pos (string-match "$" keys pos)))
                (t
                 (let ((orig-word word) (prefix 0) (bits 0))
                   (while (string-match "^[ACHMsS]-." word)
                     (setq bits (+ bits
                                   (cdr
                                    (assq (aref word 0)
                                          '((?A . ?\A-\0) (?C . ?\C-\0)
                                            (?H . ?\H-\0) (?M . ?\M-\0)
                                            (?s . ?\s-\0) (?S . ?\S-\0))))))
                     (setq prefix (+ prefix 2))
                     (setq word (substring word 2)))
                   (when (string-match "^\\^.$" word)
                     (setq bits (+ bits ?\C-\0))
                     (setq prefix (1+ prefix))
                     (setq word (substring word 1)))
                   (let ((found (assoc word '(("NUL" . "\0") ("RET" . "\r")
                                              ("LFD" . "\n") ("TAB" . "\t")
                                              ("ESC" . "\e") ("SPC" . " ")
                                              ("DEL" . "\177")))))
                     (when found (setq word (cdr found))))
                   (when (string-match "^\\\\[0-7]+$" word)
                     (let ((n 0))
                       (dolist (ch (cdr (string-to-list word)))
                         (setq n (+ (* n 8) ch -48)))
                       (setq word (vector n))))
                   (cond ((= bits 0)
                          (setq key word))
                         ((and (= bits ?\M-\0) (stringp word)
                               (string-match "^-?[0-9]+$" word))
                          (setq key (mapcar (lambda (x) (+ x bits))
                                            (append word nil))))
                         ((/= (length word) 1)
                          (error "%s must prefix a single character, not %s"
                                 (substring orig-word 0 prefix) word))
                         ((and (/= (logand bits ?\C-\0) 0) (stringp word)
                               ;; We used to accept . and ? here,
                               ;; but . is simply wrong,
                               ;; and C-? is not used (we use DEL instead).
                               (string-match "[@-_a-z]" word))
                          (setq key (list (+ bits (- ?\C-\0)
                                             (logand (aref word 0) 31)))))
                         (t
                          (setq key (list (+ bits (aref word 0)))))))))
          (when key
            (dolist (_ (number-sequence 1 times))
              (setq res (vconcat res key))))))
      res)))

;;* UNTESTED
(compat-defun keymap-set (keymap key definition)
  "Set KEY to DEFINITION in KEYMAP.
KEY is a string that satisfies `key-valid-p'.

DEFINITION is anything that can be a key's definition:
 nil (means key is undefined in this keymap),
 a command (a Lisp function suitable for interactive calling),
 a string (treated as a keyboard macro),
 a keymap (to define a prefix key),
 a symbol (when the key is looked up, the symbol will stand for its
    function definition, which should at that time be one of the above,
    or another symbol whose function definition is used, etc.),
 a cons (STRING . DEFN), meaning that DEFN is the definition
    (DEFN should be a valid definition in its own right) and
    STRING is the menu item name (which is used only if the containing
    keymap has been created with a menu name, see `make-keymap'),
 or a cons (MAP . CHAR), meaning use definition of CHAR in keymap MAP,
 or an extended menu item definition.
 (See info node `(elisp)Extended Menu Items'.)"
  :realname compat--keymap-set
  (unless (compat--key-valid-p key)
    (error "%S is not a valid key definition; see `key-valid-p'" key))
  ;; If we're binding this key to another key, then parse that other
  ;; key, too.
  (when (stringp definition)
    (unless (compat--key-valid-p key)
      (error "%S is not a valid key definition; see `key-valid-p'" key))
    (setq definition (compat--key-parse definition)))
  (define-key keymap (compat--key-parse key) definition))

;;* UNTESTED
(compat-defun keymap-unset (keymap key &optional remove)
  "Remove key sequence KEY from KEYMAP.
KEY is a string that satisfies `key-valid-p'.

If REMOVE, remove the binding instead of unsetting it.  This only
makes a difference when there's a parent keymap.  When unsetting
a key in a child map, it will still shadow the same key in the
parent keymap.  Removing the binding will allow the key in the
parent keymap to be used."
  :realname compat--keymap-unset
  (unless (compat--key-valid-p key)
    (error "%S is not a valid key definition; see `key-valid-p'" key))
  (compat--define-key-with-remove keymap (compat--key-parse key) nil remove))

;;* UNTESTED
(compat-defun keymap-global-set (key command)
  "Give KEY a global binding as COMMAND.
COMMAND is the command definition to use; usually it is
a symbol naming an interactively-callable function.

KEY is a string that satisfies `key-valid-p'.

Note that if KEY has a local binding in the current buffer,
that local binding will continue to shadow any global binding
that you make with this function."
  :note "The compatibility version of is not a command."
  (compat--keymap-set (current-global-map) key command))

;;* UNTESTED
(compat-defun keymap-local-set (key command)
  "Give KEY a local binding as COMMAND.
COMMAND is the command definition to use; usually it is
a symbol naming an interactively-callable function.

KEY is a string that satisfies `key-valid-p'.

The binding goes in the current buffer's local map, which in most
cases is shared with all other buffers in the same major mode."
  :note "The compatibility version of is not a command."
  (let ((map (current-local-map)))
    (unless map
      (use-local-map (setq map (make-sparse-keymap))))
    (compat--keymap-set map key command)))

;;* UNTESTED
(compat-defun keymap-global-unset (key &optional remove)
  "Remove global binding of KEY (if any).
KEY is a string that satisfies `key-valid-p'.

If REMOVE (interactively, the prefix arg), remove the binding
instead of unsetting it.  See `keymap-unset' for details."
  :note "The compatibility version of is not a command."
  (compat--keymap-unset (current-global-map) key remove))

;;* UNTESTED
(compat-defun keymap-local-unset (key &optional remove)
  "Remove local binding of KEY (if any).
KEY is a string that satisfies `key-valid-p'.

If REMOVE (interactively, the prefix arg), remove the binding
instead of unsetting it.  See `keymap-unset' for details."
  :note "The compatibility version of is not a command."
  (when (current-local-map)
    (compat--keymap-unset (current-local-map) key remove)))

;;* UNTESTED
(compat-defun keymap-substitute (keymap olddef newdef &optional oldmap prefix)
  "Replace OLDDEF with NEWDEF for any keys in KEYMAP now defined as OLDDEF.
In other words, OLDDEF is replaced with NEWDEF wherever it appears.
Alternatively, if optional fourth argument OLDMAP is specified, we redefine
in KEYMAP as NEWDEF those keys that are defined as OLDDEF in OLDMAP.

If you don't specify OLDMAP, you can usually get the same results
in a cleaner way with command remapping, like this:
  (define-key KEYMAP [remap OLDDEF] NEWDEF)
\n(fn OLDDEF NEWDEF KEYMAP &optional OLDMAP)"
  ;; Don't document PREFIX in the doc string because we don't want to
  ;; advertise it.  It's meant for recursive calls only.  Here's its
  ;; meaning

  ;; If optional argument PREFIX is specified, it should be a key
  ;; prefix, a string.  Redefined bindings will then be bound to the
  ;; original key, with PREFIX added at the front.
  (unless prefix
    (setq prefix ""))
  (let* ((scan (or oldmap keymap))
	 (prefix1 (vconcat prefix [nil]))
	 (key-substitution-in-progress
	  (cons scan key-substitution-in-progress)))
    ;; Scan OLDMAP, finding each char or event-symbol that
    ;; has any definition, and act on it with hack-key.
    (map-keymap
     (lambda (char defn)
       (aset prefix1 (length prefix) char)
       (substitute-key-definition-key defn olddef newdef prefix1 keymap))
     scan)))

;;* UNTESTED
(compat-defun keymap-set-after (keymap key definition &optional after)
  "Add binding in KEYMAP for KEY => DEFINITION, right after AFTER's binding.
This is like `keymap-set' except that the binding for KEY is placed
just after the binding for the event AFTER, instead of at the beginning
of the map.  Note that AFTER must be an event type (like KEY), NOT a command
\(like DEFINITION).

If AFTER is t or omitted, the new binding goes at the end of the keymap.
AFTER should be a single event type--a symbol or a character, not a sequence.

Bindings are always added before any inherited map.

The order of bindings in a keymap matters only when it is used as
a menu, so this function is not useful for non-menu keymaps."
  (unless (compat--key-valid-p key)
    (error "%S is not a valid key definition; see `key-valid-p'" key))
  (when after
    (unless (compat--key-valid-p key)
      (error "%S is not a valid key definition; see `key-valid-p'" key)))
  (define-key-after keymap (compat--key-parse key) definition
    (and after (compat--key-parse after))))

(compat-defun keymap-lookup
    (keymap key &optional accept-default no-remap position)
  "Return the binding for command KEY.
KEY is a string that satisfies `key-valid-p'.

If KEYMAP is nil, look up in the current keymaps.  If non-nil, it
should either be a keymap or a list of keymaps, and only these
keymap(s) will be consulted.

The binding is probably a symbol with a function definition.

Normally, `keymap-lookup' ignores bindings for t, which act as
default bindings, used when nothing else in the keymap applies;
this makes it usable as a general function for probing keymaps.
However, if the optional second argument ACCEPT-DEFAULT is
non-nil, `keymap-lookup' does recognize the default bindings,
just as `read-key-sequence' does.

Like the normal command loop, `keymap-lookup' will remap the
command resulting from looking up KEY by looking up the command
in the current keymaps.  However, if the optional third argument
NO-REMAP is non-nil, `keymap-lookup' returns the unmapped
command.

If KEY is a key sequence initiated with the mouse, the used keymaps
will depend on the clicked mouse position with regard to the buffer
and possible local keymaps on strings.

If the optional argument POSITION is non-nil, it specifies a mouse
position as returned by `event-start' and `event-end', and the lookup
occurs in the keymaps associated with it instead of KEY.  It can also
be a number or marker, in which case the keymap properties at the
specified buffer position instead of point are used."
  :realname compat--keymap-lookup
  (unless (compat--key-valid-p key)
    (error "%S is not a valid key definition; see `key-valid-p'" key))
  (when (and keymap position)
    (error "Can't pass in both keymap and position"))
  (if keymap
      (let ((value (lookup-key keymap (compat--key-parse key) accept-default)))
        (if (and (not no-remap)
                   (symbolp value))
            (or (command-remapping value) value)
          value))
    (key-binding (kbd key) accept-default no-remap position)))

;;* UNTESTED
(compat-defun keymap-local-lookup (keys &optional accept-default)
  "Return the binding for command KEYS in current local keymap only.
KEY is a string that satisfies `key-valid-p'.

The binding is probably a symbol with a function definition.

If optional argument ACCEPT-DEFAULT is non-nil, recognize default
bindings; see the description of `keymap-lookup' for more details
about this."
  (let ((map (current-local-map)))
    (when map
      (compat--keymap-lookup map keys accept-default))))

;;* UNTESTED
(compat-defun keymap-global-lookup (keys &optional accept-default _message)
  "Return the binding for command KEYS in current global keymap only.
KEY is a string that satisfies `key-valid-p'.

The binding is probably a symbol with a function definition.
This function's return values are the same as those of `keymap-lookup'
\(which see).

If optional argument ACCEPT-DEFAULT is non-nil, recognize default
bindings; see the description of `keymap-lookup' for more details
about this."
  :note "The compatibility version of is not a command."
  (compat--keymap-lookup (current-global-map) keys accept-default))

;;* UNTESTED
(compat-defun define-keymap (&rest definitions)
  "Create a new keymap and define KEY/DEFINITION pairs as key bindings.
The new keymap is returned.

Options can be given as keywords before the KEY/DEFINITION
pairs.  Available keywords are:

:full      If non-nil, create a chartable alist (see `make-keymap').
             If nil (i.e., the default), create a sparse keymap (see
             `make-sparse-keymap').

:suppress  If non-nil, the keymap will be suppressed (see `suppress-keymap').
             If `nodigits', treat digits like other chars.

:parent    If non-nil, this should be a keymap to use as the parent
             (see `set-keymap-parent').

:keymap    If non-nil, instead of creating a new keymap, the given keymap
             will be destructively modified instead.

:name      If non-nil, this should be a string to use as the menu for
             the keymap in case you use it as a menu with `x-popup-menu'.

:prefix    If non-nil, this should be a symbol to be used as a prefix
             command (see `define-prefix-command').  If this is the case,
             this symbol is returned instead of the map itself.

KEY/DEFINITION pairs are as KEY and DEF in `keymap-set'.  KEY can
also be the special symbol `:menu', in which case DEFINITION
should be a MENU form as accepted by `easy-menu-define'.

\(fn &key FULL PARENT SUPPRESS NAME PREFIX KEYMAP &rest [KEY DEFINITION]...)"
  (declare (indent defun))
  (let (full suppress parent name prefix keymap)
    ;; Handle keywords.
    (while (and definitions
                (keywordp (car definitions))
                (not (eq (car definitions) :menu)))
      (let ((keyword (pop definitions)))
        (unless definitions
          (error "Missing keyword value for %s" keyword))
        (let ((value (pop definitions)))
          (pcase keyword
            (:full (setq full value))
            (:keymap (setq keymap value))
            (:parent (setq parent value))
            (:suppress (setq suppress value))
            (:name (setq name value))
            (:prefix (setq prefix value))
            (_ (error "Invalid keyword: %s" keyword))))))

    (when (and prefix
               (or full parent suppress keymap))
      (error "A prefix keymap can't be defined with :full/:parent/:suppress/:keymap keywords"))

    (when (and keymap full)
      (error "Invalid combination: :keymap with :full"))

    (let ((keymap (cond
                   (keymap keymap)
                   (prefix (define-prefix-command prefix nil name))
                   (full (make-keymap name))
                   (t (make-sparse-keymap name)))))
      (when suppress
        (suppress-keymap keymap (eq suppress 'nodigits)))
      (when parent
        (set-keymap-parent keymap parent))

      ;; Do the bindings.
      (while definitions
        (let ((key (pop definitions)))
          (unless definitions
            (error "Uneven number of key/definition pairs"))
          (let ((def (pop definitions)))
            (if (eq key :menu)
                (easy-menu-define nil keymap "" def)
              (compat--keymap-set keymap key def)))))
      keymap)))

;;* UNTESTED
(compat-defmacro defvar-keymap (variable-name &rest defs)
  "Define VARIABLE-NAME as a variable with a keymap definition.
See `define-keymap' for an explanation of the keywords and KEY/DEFINITION.

In addition to the keywords accepted by `define-keymap', this
macro also accepts a `:doc' keyword, which (if present) is used
as the variable documentation string.

\(fn VARIABLE-NAME &key DOC FULL PARENT SUPPRESS NAME PREFIX KEYMAP &rest [KEY DEFINITION]...)"
  (declare (indent 1))
  (let ((opts nil)
        doc)
    (while (and defs
                (keywordp (car defs))
                (not (eq (car defs) :menu)))
      (let ((keyword (pop defs)))
        (unless defs
          (error "Uneven number of keywords"))
        (if (eq keyword :doc)
            (setq doc (pop defs))
          (push keyword opts)
          (push (pop defs) opts))))
    (unless (zerop (% (length defs) 2))
      (error "Uneven number of key/definition pairs: %s" defs))
    `(defvar ,variable-name
       (define-keymap ,@(nreverse opts) ,@defs)
       ,@(and doc (list doc)))))

(provide 'compat-29)
;;; compat-29.el ends here
