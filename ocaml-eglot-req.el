;;; ocaml-eglot-req.el --- LSP custom request   -*- coding: utf-8; lexical-binding: t -*-

;; Copyright (C) 2024  Xavier Van de Woestyne
;; Licensed under the MIT license.

;; Author: Xavier Van de Woestyne <xaviervdw@gmail.com>
;; Created: 20 September 2024
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Set of functions for interacting with the ocaml-lsp-server via
;; JSONRPC requests.  This module is internal and part of the
;; ocaml-eglot project.  An add-on to the Emacs Eglot LSP client for
;; editing OCaml code.

;;; Code:

(require 'cl-lib)
(require 'eglot)
(require 'ocaml-eglot-util)
(require 'jsonrpc)

;;; Low-level plumbing to execute a request

(defun ocaml-eglot-req--current-server ()
  "Return current logical Eglot server connection or error."
  (eglot--current-server-or-lose))

(cl-defun ocaml-eglot-req--send (method params &key
                                        immediate
                                        timeout
                                        cancel-on-input
                                        cancel-on-input-retval)
  "Execute a custom request on the current LSP server.
METHOD is the dedicated lsp server request, PARAMS is the parameters of the
query, IMMEDIATE is a flag to trigger the request only if the document has
changed, TIMEOUT is a timeout time response.  CANCEL-ON-INPUT and
CANCEL-ON-INPUT-RETVAL are hooks for cancellation."
  (let ((server (ocaml-eglot-req--current-server)))
    (unless immediate (eglot--signal-textDocument/didChange))
    (jsonrpc-request server method params
                     :timeout timeout
                     :cancel-on-input cancel-on-input
                     :cancel-on-input-retval cancel-on-input-retval)))

;;; Parameters structures

(defun ocaml-eglot-req--TextDocumentIdentifier ()
  "Compute `TextDocumentIdentifier' object for current buffer."
  (eglot--TextDocumentIdentifier))

(defun ocaml-eglot-req--PlainUri ()
  "A hack for requests that do not respect the URI parameter scheme."
  (make-vector 1 (ocaml-eglot-util--current-uri)))

(defun ocaml-eglot-req--TextDocumentPositionParams ()
  "Compute `TextDocumentPositionParams' object for the current buffer."
  (append
   (eglot--TextDocumentPositionParams)
   (ocaml-eglot-req--TextDocumentIdentifier)))

(defun ocaml-eglot-req--TextDocumentPositionParamsWithPos (position)
  "Compute `TextDocumentPositionParams' object for the current buffer.
With a given POSITION"
  (append (list :textDocument (ocaml-eglot-req--TextDocumentIdentifier)
                :position position)
          (ocaml-eglot-req--TextDocumentIdentifier)))

(defun ocaml-eglot-req--ConstructParams (position depth with-local-values)
  "Compute `ConstructParams' object for current buffer.
POSITION the position of the hole.
DEPTH is the depth of the search (default is 1).
WITH-LOCAL-VALUES is a flag for including local values in construction."
  (append (ocaml-eglot-req--TextDocumentPositionParamsWithPos position)
          `(:depth, depth)
          `(:withValues, with-local-values)))

(defun ocaml-eglot-req--SearchParams (query limit with-doc markup-kind)
  "Compute the `SearchParams' object for the current buffer.
QUERY is the requested type-search query and LIMIT is the number of
results to return.  If WITH-DOC is non-nil, the documentation will be
included and the documentation output can be set using MARKUP-KIND."
  (append (ocaml-eglot-req--TextDocumentPositionParams)
          `(:query, query)
          `(:limit, limit)
          `(:with_doc, with-doc)
          `(:doc_dormat, markup-kind)))

(defun ocaml-eglot-req--GetDocumentationParam (identifier markup-kind)
  "Compute the `GetDocumentationParam'.
A potential IDENTIFIER can be given and MARKUP-KIND can be parametrized."
  (let ((params (append (ocaml-eglot-req--TextDocumentPositionParams)
                        `(:contentFormat, markup-kind))))
    (if identifier (append params `(:identifier, identifier))
      params)))

;;; Concrete requests

(defun ocaml-eglot-req--jump ()
  "Execute the `ocamllsp/jump' request."
  (let ((params (ocaml-eglot-req--TextDocumentPositionParams)))
    (ocaml-eglot-req--send :ocamllsp/jump params)))

(defun ocaml-eglot-req--construct (position depth with-local-value)
  "Execute the `ocamllsp/construct' request for a given POSITION.
DEPTH and WITH-LOCAL-VALUE can be parametrized."
  (let ((params (ocaml-eglot-req--ConstructParams
                 position depth with-local-value)))
    (ocaml-eglot-req--send :ocamllsp/construct params)))

(defun ocaml-eglot-req--search (query limit with-doc markup-kind)
  "Execute the `ocamllsp/typeSearch' request with a QUERY and a LIMIT.
If WITH-DOC is not nil, it include the documentation in the result.
The markup used to format documentation can be set using MARKUP-KIND."
  (let ((params
         (ocaml-eglot-req--SearchParams query limit with-doc markup-kind)))
    (append (ocaml-eglot-req--send :ocamllsp/typeSearch params) nil)))

(defun ocaml-eglot-req--holes ()
  "Execute the `ocamllsp/typedHoles' request."
  (let ((params (ocaml-eglot-req--TextDocumentIdentifier)))
    (append (ocaml-eglot-req--send :ocamllsp/typedHoles params) nil)))

(defun ocaml-eglot-req--switch-file (uri)
  "Execute the `ocamllsp/switchImplIntf' request with a given URI."
  (let ((params (make-vector 1 uri)))
    (ocaml-eglot-req--send :ocamllsp/switchImplIntf params)))

(defun ocaml-eglot-req--infer-intf (uri)
  "Execute the `ocamllsp/inferIntf' request with a given URI."
  (let ((params (make-vector 1 uri)))
    (ocaml-eglot-req--send :ocamllsp/inferIntf params)))

(defun ocaml-eglot-req--get-documentation (identifier markup-kind)
  "Execute the `ocamllsp/getDocumentation'.
If IDENTIFIER is non-nil, it documents it, otherwise, it use the identifier
under the cursor.  The MARKUP-KIND can also be configured."
  (let ((params (ocaml-eglot-req--GetDocumentationParam
                 identifier
                 markup-kind)))
    (ocaml-eglot-req--send :ocamllsp/getDocumentation params)))

(provide 'ocaml-eglot-req)
;;; ocaml-eglot-req.el ends here
