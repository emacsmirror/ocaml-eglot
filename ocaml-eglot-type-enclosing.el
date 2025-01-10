;;; ocaml-eglot-type-enclosing.el --- Type Enclosing feature   -*- coding: utf-8; lexical-binding: t -*-

;; Copyright (C) 2024-2025  Xavier Van de Woestyne
;; Licensed under the MIT license.

;; Author: Xavier Van de Woestyne <xaviervdw@gmail.com>
;; Created: 10 January 2025
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Plumbing needed to implement the primitives related to type
;; enclosing commands.

;;; Code:

(require 'cl-lib)
(require 'ocaml-eglot-util)
(require 'ocaml-eglot-req)

;;; Customizable variables

(defcustom ocaml-eglot-type-buffer-name "*ocaml-eglot-types*"
  "The name of the buffer storing types."
  :group 'ocaml-eglot
  :type 'string)

;;; Internal variables

(defvar-local ocaml-eglot-enclosing-types nil
  "Current list of enclosings related to types.")

(defvar-local ocaml-eglot-current-type nil
  "Current type for the current enclosing.")

(defvar-local ocaml-eglot-enclosing-offset 0
  "The offset of the requested enclosings.")

;;; Key mapping for type enclosing

(defvar ocaml-eglot-type-enclosing-map
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap (kbd "C-<up>") #'ocaml-eglot-type-enclosing-grow)
    (define-key keymap (kbd "C-<down>") #'ocaml-eglot-type-enclosing-shrink)
    (define-key keymap (kbd "C-w") #'ocaml-eglot-type-enclosing-copy)
    keymap))

;;; Internal functions

(defun ocaml-eglot-type-enclosing-copy ()
  "Copy the type of the current enclosing to the Kill-ring."
  (interactive)
  (when ocaml-eglot-current-type
    (eglot--message "Copied `%s' to kill-ring" ocaml-eglot-current-type)
    (kill-new ocaml-eglot-current-type)))

(defun ocaml-eglot-type-enclosing--with-fixed-offset ()
  "Compute the type enclosing for a dedicated offset."
  (let* ((verbosity nil)
         (index ocaml-eglot-enclosing-offset)
         (at (ocaml-eglot-util--current-position-or-range))
         (result (ocaml-eglot-req--type-enclosings at index verbosity))
         (type (cl-getf result :type)))
    (setq ocaml-eglot-current-type type)
    (ocaml-eglot-type-enclosing--display type)))

(defun ocaml-eglot-type-enclosing-grow ()
  "Growing of the type enclosing."
  (interactive)
  (when ocaml-eglot-enclosing-types
    (if (>= ocaml-eglot-enclosing-offset
            (1- (length ocaml-eglot-enclosing-types)))
        (setq ocaml-eglot-enclosing-offset 0)
      (setq ocaml-eglot-enclosing-offset (1+ ocaml-eglot-enclosing-offset)))
    (ocaml-eglot-type-enclosing--with-fixed-offset)))

(defun ocaml-eglot-type-enclosing-shrink ()
  "Shrinking of the type enclosing."
  (interactive)
  (when ocaml-eglot-enclosing-types
    (if (<= ocaml-eglot-enclosing-offset 0)
        (setq ocaml-eglot-enclosing-offset
              (1- (length ocaml-eglot-enclosing-types)))
      (setq ocaml-eglot-enclosing-offset (1- ocaml-eglot-enclosing-offset)))
    (ocaml-eglot-type-enclosing--with-fixed-offset)))

(defun ocaml-eglot-type-enclosing--type-buffer (type-expr)
  "Create buffer with content TYPE-EXPR of the enclosing type buffer."
  (let ((curr-dir default-directory)
        (current-major-mode major-mode))
    (with-current-buffer (get-buffer-create ocaml-eglot-type-buffer-name)
      (funcall current-major-mode)
      (read-only-mode 0)
      (erase-buffer)
      (insert type-expr)
      (goto-char (point-min))
      (read-only-mode 1)
      (setq default-directory curr-dir))))

(defun ocaml-eglot-type-enclosing--display (type-expr)
  "Display the type-enclosing for TYPE-EXPR in a dedicated buffer."
  (let ((current-enclosing (aref ocaml-eglot-enclosing-types
                                 ocaml-eglot-enclosing-offset)))
    (ocaml-eglot-type-enclosing--type-buffer type-expr)
    (if (ocaml-eglot-util--text-less-than type-expr 8)
        (message "%s" (with-current-buffer ocaml-eglot-type-buffer-name
                        (font-lock-fontify-region (point-min) (point-max))
                        (buffer-string)))
      (display-buffer ocaml-eglot-type-buffer-name))
    (ocaml-eglot-util--highlight-range current-enclosing
                                       'ocaml-eglot-highlight-region-face)))

(defun ocaml-eglot-type-enclosing--reset ()
  "Reset local variables defined by the enclosing query."
  (setq ocaml-eglot-current-type nil)
  (setq ocaml-eglot-enclosing-types nil)
  (setq ocaml-eglot-enclosing-offset 0))

(defun ocaml-eglot-type-enclosing--call ()
  "Prepare the type-enclosings computation request."
  (ocaml-eglot-type-enclosing--reset)
  (let* ((verbosity nil)
         (index 0)
         (at (ocaml-eglot-util--current-position-or-range))
         (result (ocaml-eglot-req--type-enclosings at index verbosity))
         (type (cl-getf result :type))
         (enclosings (cl-getf result :enclosings)))
    (setq ocaml-eglot-enclosing-offset index)
    (setq ocaml-eglot-enclosing-types enclosings)
    (setq ocaml-eglot-current-type type)
    (ocaml-eglot-type-enclosing--display type)
    (set-transient-map ocaml-eglot-type-enclosing-map t
                       'ocaml-eglot-type-enclosing--reset)))

(provide 'ocaml-eglot-type-enclosing)
;;; ocaml-eglot-type-enclosing.el ends here
