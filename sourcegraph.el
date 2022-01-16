;;; sourcegraph.el --- Emacs integration with Sourcegraph -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Daniel Martín

;; Author: Daniel Martín <mardani29@yahoo.es>
;; URL: https://github.com/danielmartin/sourcegraph
;; Keywords: programming
;; Version: 0.50
;; Package-Requires: ((emacs "25.1"))

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

;; This library integrates Emacs with Sourcegraph
;; (https://github.com/sourcegraph/sourcegraph), a code search and
;; navigation engine.  It provides commands such as
;; `sourcegraph-open-in-browser', which opens the current source file
;; (line or selection) in Sourcegraph, or `sourcegraph-search', which
;; performs a search query in Sourcegraph.  It only supports git
;; version control for now.
;;
;; Instructions:
;;
;; Add this file to your `load-path' and require it:
;;
;;  (require 'sourcegraph)
;;
;; Configure the `sourcegraph-url' variable so that it points to the
;; URL where the Sourcegraph instance is running:
;;
;;  (setq sourcegraph-url "https://sourcegraph_URL_or_IP")
;;
;; If you want to enable the minor mode for every programming language
;; mode, add the following form:
;;
;;  (add-hook 'prog-mode-hook 'sourcegraph-mode)
;;
;; TODO:
;;
;;   - Implement an Xref backend that is based on the Sourcegraph API?
;;   - Org-babel integration: Add support for Sourcegraph code blocks
;;     that contain links.  Those links resolve into actual source
;;     code.

;;; Code:

(require 'subr-x)

;; Customize

(defgroup sourcegraph nil
  "Minor mode for working with Sourcegraph."
  :group 'external)

(defcustom sourcegraph-url ""
  "URL of the Sourcegraph instance."
  :group 'sourcegraph
  :type 'string)

(defcustom sourcegraph-git-executable "git"
  "Path to the git executable."
  :group 'sourcegraph
  :type 'string)


;; Git helpers

(defun sourcegraph--git-controlled-p (repo)
  "Return whether REPO is a directory under git version control."
  (locate-dominating-file repo ".git"))

(defun sourcegraph--git-run (command repo &rest args)
  "Run the given git COMMAND on REPO synchronously."
  (let ((default-directory repo))
    (with-temp-buffer
      (let* ((git-args (append (list command) args))
             (exit-code
              (apply
	       #'process-file
               (append
                (list sourcegraph-git-executable nil (current-buffer) nil)
                git-args))))
        (unless (eq exit-code 0)
          (error
           "%s %s output: %s"
           sourcegraph-git-executable
           (mapconcat 'identity git-args " ")
           (buffer-substring-no-properties (point-min) (point-max))))
        (string-remove-suffix "\n"
         (buffer-substring-no-properties (point-min) (point-max)))))))

(defun sourcegraph--git-get-remote-url (remote repo)
  "Return the URL of a given REMOTE in REPO."
  (condition-case-unless-debug err
      (sourcegraph--git-run "remote" repo "get-url" remote)
    (error
     (error "Can't get remote url for '%s': %s" remote err))))

(defun sourcegraph--git-get-local-branch (repo)
  "Return the checked out branch in REPO."
  (condition-case-unless-debug err
      (sourcegraph--git-run "rev-parse" repo "--abbrev-ref" "HEAD")
    (error
     (error "Can't get local branch for repo '%s': %s" repo err))))

(define-error 'sourcegraph-no-remotes-error "No configured remotes")

(defun sourcegraph--git-get-remotes (repo)
  "Return the list of remotes for REPO.
Signals an error if there are no remotes in REPO."
  (condition-case-unless-debug err
      (let ((remotes (sourcegraph--git-run "remote" repo)))
	(when (string-empty-p remotes)
	  (signal 'sourcegraph-no-remotes-error '(repo)))
	(split-string remotes))
    (error
     (error "Can't get list of remotes for repo '%s': %s" repo err))))

(defun sourcegraph--git-get-upstream-remote-branch (repo)
  "Return the upstream remote and branch for the checked out branch in REPO."
  (condition-case-unless-debug err
      (sourcegraph--git-run "rev-parse" repo "--abbrev-ref" "HEAD@{upstream}")
    (error
     (error "Can't get remote/branch for repo '%s': %s" repo err))))

(defun sourcegraph--git-ask-remote (branch repo)
  "Ask the user to choose a remote where BRANCH in REPO is pushed.
This logic is used when we can't determine the remote
automatically."
  (completing-read (format "Choose a remote for '%s': " branch)
		   (sourcegraph--git-get-remotes repo)
		   nil
		   t))

(defun sourcegraph--git-get-upstream-remote (branch repo)
  "Return the upstream remote for BRANCH in REPO."
  (condition-case-unless-debug err
      (if-let ((remote-and-branch
		(sourcegraph--git-get-upstream-remote-branch repo))
	       (beg-of-branch
		(string-match (regexp-quote branch) remote-and-branch nil t)))
	  (substring remote-and-branch 0 (1- beg-of-branch))
        (sourcegraph--git-ask-remote branch repo))
    (sourcegraph-no-remotes-error
     (signal (car err) (cdr err)))
    (error
     (sourcegraph--git-ask-remote branch repo))))

(defun sourcegraph--git-get-repo-root (dir)
  "Return the root of the git repository that contains DIR."
  (locate-dominating-file dir ".git"))

(defun sourcegraph--git-get-branch-and-remote-url (repo)
  "Return the current branch and remote URL in REPO."
  (let* ((branch (sourcegraph--git-get-local-branch repo))
         (remote (sourcegraph--git-get-upstream-remote branch repo))
         (remote-url (sourcegraph--git-get-remote-url remote repo)))
    (list branch remote-url)))


;; Helpers

(defun sourcegraph--default-search-query ()
  "Return the default thing to search for.
If the region is active, return that.  Otherwise, return the
symbol at point."
  (if (use-region-p)
      (buffer-substring-no-properties (region-beginning) (region-end))
    (when-let ((symbol (symbol-at-point)))
      (substring-no-properties (symbol-name symbol)))))

;; Main commands

;;;###autoload
(define-minor-mode sourcegraph-mode
  "Minor mode to integrate Emacs with Sourcegraph."
  :lighter " Sourcegraph"
  :keymap (make-sparse-keymap))

(easy-menu-define sourcegraph-menu sourcegraph-mode-map
  "Menu for Sourcegraph commands."
  '("Sourcegraph"
    ["Open in Sourcegraph" sourcegraph-open-in-browser
     :help "Opens the current file in the configured Sourcegraph instance"]
    ["Search in Sourcegraph" sourcegraph-search
     :help "Searches for a term in the configured Sourcegraph instance"]))

;;;###autoload
(defun sourcegraph-open-in-browser (&optional start end)
  "Open the region between START and END in Sourcegraph."
  (interactive (progn
                 (if (use-region-p)
                     (list (region-beginning) (region-end))
                   (list (point) (point)))))
  (unless (executable-find sourcegraph-git-executable t)
    (user-error "Git is not installed or not in the `exec-path'"))
  (when (string-empty-p sourcegraph-url)
    (user-error "The `sourcegraph-url' variable is not configured"))
  (unless buffer-file-name
    (user-error "The current buffer is not visiting a file"))
  (let* ((point-begin start)
	 (point-end
	  (if (eq (char-before end) ?\n)
	      (- end 1)
	    end))
	 (start-row (1- (line-number-at-pos point-begin)))
         (end-row (1- (line-number-at-pos point-end)))
         (start-col (save-excursion (goto-char point-begin) (current-column)))
         (end-col (save-excursion (goto-char point-end) (current-column)))
         (repo (sourcegraph--git-get-repo-root default-directory)))
    (when (or (not repo)
              (string-empty-p repo))
      (error "The current directory is not under git version control"))
    (seq-let (branch remote-url)
        (sourcegraph--git-get-branch-and-remote-url repo)
      (when (or (string-empty-p branch)
                (string-empty-p remote-url))
        (error
         "Empty response from the command to get the branch or remote url"))
      (let ((url
             (url-encode-url
              (format (concat "%s/-/editor?remote_url=%s&branch=%s&file=%s"
                              "&editor=Emacs&version=%s&start_row=%s"
                              "&start_col=%s&end_row=%s&end_col=%s")
                      sourcegraph-url
                      remote-url
                      branch
                      (file-relative-name buffer-file-name repo)
                      "1"
                      start-row
                      start-col
                      end-row
                      end-col))))
        (browse-url url)))))

;;;###autoload
(defun sourcegraph-search (query)
  "Search for QUERY in Sourcegraph."
  (interactive (list
                (read-string
                 (format "Search in Sourcegraph (default %s): "
                         (sourcegraph--default-search-query))
                 nil nil (sourcegraph--default-search-query))))
  (when (string-empty-p sourcegraph-url)
    (user-error "The `sourcegraph-url' variable is not configured"))
  (let ((url
         (url-encode-url
          (format "%s/search?patternType=literal&q=%s"
                  sourcegraph-url
                  query))))
    (browse-url url)))

(provide 'sourcegraph)
;;; sourcegraph.el ends here
