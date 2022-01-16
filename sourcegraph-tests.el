;;; sourcegraph-tests.el --- Emacs integration with Sourcegraph -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Daniel Martín

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

(require 'ert)
(require 'sourcegraph)

(ert-deftest sourcegraph--git-local-branch-test ()
  (skip-unless (executable-find sourcegraph-git-executable))
  (let* ((repo (locate-dominating-file default-directory ".git"))
         (result (sourcegraph--git-get-local-branch repo)))
    (should (equal result "main"))))

(provide 'sourcegraph-tests)

;; sourcegraph-tests.el ends here
