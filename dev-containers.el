;;; dev-containers.el --- Control the devcontainer cli from your editor *- lexical-binding: t -*-

;; Author: Alexis Purslane <alexispurlsane@pm.me>
;; URL: https://github.com/alexispurslane/emacs-dev-containers
;; Package-Requires: ((emacs "29") (cl-lib "1.0") (hydra "0.15.0") (tramp "2.6") (project "0.9"))
;; Version: 0.2.0
;; Keywords: dev-containers, containers, vscode, devcontainers

;; This file is not part of GNU Emacs.

;; Copyright (c) by Alexis Purslane 2024.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; For more information, see the README in the online repository.

;;; Code:

(require 'cl-lib)
(require 'hydra)
(require 'tramp)
(require 'project)

(defgroup dev-containers nil
    "Customization group for the Emacs dev-containers package."
    :group 'external)

(defcustom dev-containers--container-executable
    (executable-find "podman")
    "The location that dev-containers.el finds your fundamental
container management executable (e.g., docker or podman)."
    :group 'dev-containers
    :type 'string)

(defcustom dev-containers--devcontainer-executable
    (executable-find "devcontainer")
    "The location that dev-containers.el finds your `devcontainer'
executable."
    :group 'dev-containers
    :type 'string)

(defmacro dev-containers--defsubcommand (subcommand &optional arg-spec &rest args)
    "Generate a command definition for the given devcontainer
SUBCOMMAND with the given ARG-SPEC and ARGS."
    `(defun ,(intern (concat "dev-containers-" (string-replace " " "-" subcommand))) (,@args)
         ,(concat "Run the \=devcontainer "
                  subcommand
                  " "
                  (string-join (mapcar (lambda (arg) (upcase (symbol-name arg))) args) " ")
                  "\= command.")
         (interactive ,arg-spec)
         (message ,(concat "Running " subcommand "..."))
         (set-process-sentinel
          (start-process "devcontainer" "*devcontainer*"
                         dev-containers--devcontainer-executable
                         ,subcommand "--workspace-folder" (project-root (project-current)) ,@args)
          (lambda (process msg)
              (pcase (list (process-status process) (process-exit-status process))
                  ('(exit 0) (message "Devcontainer command succeeded."))
                  (_ (message (concat "Devcontainer command failed with message: " msg " (check *devcontainer* for more info)"))))))))

(dev-containers--defsubcommand "up")
(dev-containers--defsubcommand "set-up")
(dev-containers--defsubcommand "run-user-commands")
(dev-containers--defsubcommand "read-configuration")
(dev-containers--defsubcommand "outdated")
(dev-containers--defsubcommand "upgrade")
(dev-containers--defsubcommand "build")
(dev-containers--defsubcommand "exec"
                               (list
                                (read-shell-command "Shell command to run in devcontainer: "
                                                    nil
                                                    t))
                               shellcmd)

(dev-containers--defsubcommand "features test"
                               (list (read-string "Feature to test: "))
                               feature)
(dev-containers--defsubcommand "features package"
                               (list (read-string "Feature to package: "))
                               feature)
(dev-containers--defsubcommand "features publish"
                               (list (read-string "Feature to package and publish: "))
                               feature)
(dev-containers--defsubcommand "features info"
                               (list
                                (read-string "Mode: ")
                                (read-string "Feature to package and publish: "))
                               mode feature)
(dev-containers--defsubcommand "features resolve-dependencies")
(dev-containers--defsubcommand "features generate-docs")
;; My abstraction wasn't quite powerful enough for this one, and tbh... I don't care.
(defun dev-containers-templates-apply (template-id)
    "Run the \=devcontainer templates apply --template-id TEMPLATE-ID\= command."
    (interactive (list (read-string "OCI template reference: ")))
    (message "Running templates apply...")
    (set-process-sentinel
     (start-process "devcontainer" "*devcontainer*"
                    dev-containers--devcontainer-executable
                    "templates apply"
                    "--workspace-folder" (project-root (project-current))
                    "--template-id" template-id)
     (lambda (process msg)
         (pcase (list (process-status process) (process-exit-status process))
             ('(exit 0) (message "Devcontainer command succeeded."))
             (_ (message (concat "Devcontainer command failed with message: " msg " (check *devcontainer* for more info)")))))))
(dev-containers--defsubcommand "templates publish"
                               (list (read-file-name "Devcontainer.json or directory of json files: "))
                               publish-it)
(dev-containers--defsubcommand "templates generate-docs")

(defmacro dev-containers--open-hydra (hydra)
    "Call a hydra."
    `(progn
         (call-interactively ',hydra)))

(defhydra dev-containers-features-hydra (:color blue :columns 2)
    "Run a `devcontainer features' CLI command"
    ("t" dev-containers-features-test "Test Features")
    ("p" dev-containers-features-package "Package Features")
    ("P" dev-containers-features-publish "Package and publish Features")
    ("i" dev-containers-features-info "Fetch metadata for a published Feature")
    ("d" dev-containers-features-resolve-dependencies "Read and resolve dependency graph from a configuration")
    ("h" dev-containers-features-generate-docs "Generate documentation"))

(defhydra dev-containers-templates-hydra (:color blue :columns 2)
    "Run a `devcontainer templates' CLI command"
    ("a" dev-containers-templates-apply "Apply a template to the project")
    ("p" dev-containers-templates-publish "Package and publish templates")
    ("h" dev-containers-templates-generate-docs "Generate documentation"))

(defhydra dev-containers-hydra (:color blue :columns 2)
    "Run a command with the `devcontainer' CLI tool"
    ("u" dev-containers-up "Create and run dev container")
    ("s" dev-containers-set-up "Set up an existing container as a dev container")
    ("b" dev-containers-build "Build a dev container image")
    ("r" dev-containers-run-user-commands "Run user commands")
    ("c" dev-containers-read-configuration "Read configuration")
    ("o" dev-containers-outdated "Show current and available versions")
    ("U" dev-containers-upgrade "Upgrade lockfile")
    ("f" (dev-containers--open-hydra dev-containers-features-hydra/body) "Features commands")
    ("t" (dev-containers--open-hydra dev-containers-templates-hydra/body) "Tempaltes commands")
    ("e" dev-containers-exec "Execute a command on a running dev container")
    ("q" nil "cancel" :color magenta))

(defun dev-containers--tramp-completion (&optional ignored)
    "Gets the list of available (running) containers for use as
completion options with the /devcontainer: tramp method."
    (mapcar (lambda (x) (list nil x))
            (process-lines dev-containers--container-executable "ps" "--noheading" "--format" "{{.Names}}")))

(define-minor-mode dev-containers-minor-mode
    "A minor mode for controlling the `devcontainer' CLI tool."
    :initial-value nil
    :lighter " Devcontainer"
    :keymap `((,(kbd "C-c $") . dev-containers-hydra/body))
    (add-to-list 'tramp-remote-path 'tramp-own-remote-path)
    (add-to-list 'tramp-methods
                 `("devcontainer" . ((tramp-login-program "devcontainer")
                                     (tramp-login-args
                                      (("exec")
                                       ("--workspace-folder" ".")
                                       ("--container-id" "%h")
                                       ("%l")))
                                     (tramp-remote-shell "/bin/sh")
                                     (tramp-remote-shell-login "-l")
                                     (tramp-remote-shell-args ("-i" "-c")))))
    (tramp-set-completion-function "devcontainer" '((dev-containers--tramp-completion ""))))

(provide 'dev-containers)
;;; dev-containers.el ends here
