;; prevent gc during startup
(setq gc-cons-threshold 402653184
      gc-cons-percentage 0.6)
(add-hook 'after-init-hook (lambda () (setq gc-cons-threshold 800000
					    gc-cons-percentage 0.1)))

(require 'package)
(setq package-enable-at-startup nil)
(setq package-archives '(("org"   . "http://orgmode.org/elpa/")
			 ("gnu"   . "http://elpa.gnu.org/packages/")
			 ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

;; use-package this?
(global-auto-revert-mode 1)

;; UI configurations
(scroll-bar-mode -1)

(tool-bar-mode   -1)
(tooltip-mode    -1)
(menu-bar-mode   -1)

(setq backup-directory-alist `(("." . "~/.saves")))
(setq delete-old-versions t
      kept-new-versions 6
      kept-old-versions 2
      version-control t)
(setq backup-by-copying-when-linked t)

(let ((secret.el (expand-file-name ".secret.el" user-emacs-directory)))
  (when (file-exists-p secret.el)
    (load secret.el)))

(setq-default custom-file (expand-file-name ".custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

(set-face-attribute 'default nil
		    :family "Source Code Pro"
		    ;; :height 160 ;; external monitor
		    :height 170 ;; coffee shop
		    :weight 'normal
		    :width 'normal)

;; TODO move this to helm
(defun my-proj-relative-buf-name ()
  (ignore-errors
    (rename-buffer
     (file-relative-name buffer-file-name (projectile-project-root)))))

(add-hook 'find-file-hook #'my-proj-relative-buf-name)

;; org mode large files super slow without doing this
(setq-default bidi-paragraph-direction nil)

;; make helm buffer candidates sane
;; todo put in helm use-package block
(defun helm-buffers-sort-transformer@donot-sort (_ candidates _)
  candidates)
(advice-add 'helm-buffers-sort-transformer :around 'helm-buffers-sort-transformer@donot-sort)


;; enable winner-mode
;; TODO use-package this
(when (fboundp 'winner-mode)
  (winner-mode 1))


(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(use-package evil
  :init
  (setq evil-want-integration t) ;; This is optional since it's already set to t by default.
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-scroll t)
  ;; make * over a symbol look for other instances
  (setq evil-symbol-word-search t)
  :config
  (evil-set-initial-state 'org-agenda-mode 'normal)
  (evil-mode 1))

(use-package org
  :config
  (setq org-agenda-files '("~/bsab"))
  (setq org-file-apps '(("\\.log\\'" . emacs)))
  (setq org-hide-leading-stars t)
  (org-babel-do-load-languages 'org-babel-load-languages '(
							   (sql . t)
							   (shell . t)
							   (mongo . t)
							   (restclient . t)
							   ))
  (setq org-confirm-babel-evaluate nil) 
  (setq org-babel-default-header-args:sh
	'((:prologue . "exec 2>&1") (:epilogue . ":")) ;; TODO is there a way to add default header args here?
	)
  (setq org-babel-default-header-args:shell
	'((:prologue . "export DOCKER_COMPOSE_NO_TTY=1; exec 2>&1") (:epilogue . ":"))
	)
  (setq org-refile-targets
	'((org-agenda-files . (:maxlevel . 4))))
  (setq org-indirect-buffer-display 'current-window)
  (setq org-startup-align-all-tables t)
  (setq org-startup-indented t)
  (setq org-log-done t)

  ;; START org babel sh async file log
  (defun my-pass-it-on-filter (filePath proc str)
    "Process each line produced by PROC in STR."
    (interactive)
    (when (buffer-live-p (process-buffer proc))
      (with-current-buffer (process-buffer proc)
	(insert str)
	(goto-char (point-min))
	(while (progn (skip-chars-forward "^\n")
		      (not (eobp)))
	  (ignore-errors
	    (let ((result (delete-and-extract-region (point-min) (point))))
	      (delete-char 1)
	      ;; (message (format "writing result '%s' w/newline to %s" result filePath))
	      (when (not (file-exists-p filePath))
		(write-region "" nil filePath))
	      (write-region (concat result "\n") nil filePath 'append)
	      result))))))

  (defun get-parent-heading-title ()
    (ignore-errors
      (save-excursion
	(org-evil-motion-up-heading)
	(org-element-property :title (org-element-at-point)))))

  (defun get-grandparent-heading-title ()
    (ignore-errors
      (save-excursion
	(org-evil-motion-up-heading)
	(org-evil-motion-up-heading)
	(org-element-property :title (org-element-at-point)))
      ))

  (defun get-great-grandparent-heading-title ()
    (ignore-errors
      (save-excursion
	(org-evil-motion-up-heading)
	(org-evil-motion-up-heading)
	(org-evil-motion-up-heading)
	(org-element-property :title (org-element-at-point)))
      ))

  (defun cleanup-dir-name (dir)
    (replace-regexp-in-string " " "-" dir))

  (defun my-create-non-existent-directory ()
    (let ((parent-directory (file-name-directory buffer-file-name)))
      (when (not (file-exists-p parent-directory))
	(make-directory parent-directory t))))

  (defun generate-automatic-log-name ()
    ;; TODO make this take the parent org element and use its heading text in this log name
    (let* ((time-with-millis (format-time-string "%H.%M.%S.%3N"))
	   (year-month-day (format-time-string "%Y-%m-%d"))
	   (parent-element-title (get-parent-heading-title))
	   (grandparent-element-title (get-grandparent-heading-title))
	   (great-grandparent-element-title (get-great-grandparent-heading-title))
	   (descriptive-string (if (> 20 (length parent-element-title)) (format "%s_%s" grandparent-element-title parent-element-title) parent-element-title))
	   (descriptive-string-2 (if (> 20 (length descriptive-string)) (format "%s_%s" great-grandparent-element-title descriptive-string) descriptive-string))
	   (descriptive-string-safe (cleanup-dir-name descriptive-string-2))
	   (file-path (format "/Users/codygman/console/%s/%s.%s.%s.log" year-month-day descriptive-string-safe year-month-day time-with-millis))
	   (directory-path (file-name-directory file-path))
	   )
      ;; create directory if it doesn't exist
      (when (not (file-exists-p directory-path))
	(make-directory directory-path t))
      ;; use log extension since I know those links will open in emacs
      file-path))

  (defun current-line-empty-p ()
    (save-excursion
      (beginning-of-line)
      (looking-at "[[:space:]]*$")))

  (defun insert-previous-src-block-below ()
    (interactive)
    (save-excursion
      (org-evil-motion-backward-block-begin)
      ;; if we aren't at a source block or at top of file keep going to previous block
      (while (and
	      (not (org-element-property :language (org-element-at-point)))
	      (> (point) (point-min))) ;; our point is more than beginning of buffer
	(org-evil-motion-backward-block-begin)
	)
      (org-cycle)
      (org-kill-line)
      (evil-paste-after 1))
    ;; (evil-append-line 1)
    (if (current-line-empty-p)	
	(call-interactively 'evil-paste-after)
      (progn (evil-open-below 1)
	     (call-interactively 'evil-paste-before)))
    (evil-normal-state)
    (evil-previous-line)
    (evil-first-non-blank))

  (defun directory-to-write-progress (params)
    ;; if params has :log then autogenerate based on date, time, and immediate parent heading text
    (cond
     ((assq :autolog params)
      (message "autolog present, generating automatic log path and populating :file")
      (generate-automatic-log-name))
     ((cdr (assq :file params))
      (message "no autolog just returning :file specified")
      (cdr (assq :file params)))
     (t
      (message "no :file or :autolog returning nil")
      nil)))

  (defun org-babel-sh-evaluate (session body &optional params stdin cmdline)
    "Pass BODY to the Shell process in BUFFER.
If RESULT-TYPE equals `output' then return a list of the outputs
of the statements in BODY, if RESULT-TYPE equals `value' then
return the value of the last statement in BODY."
    (let* ((shebang (cdr (assq :shebang params)))
	   (results
	    (cond
	     ((or stdin cmdline)	       ; external shell script w/STDIN
	      ;; (map-put params :file file-to-write-progress) ;; TODO htis should happen in one place
	      (let ((script-file (org-babel-temp-file "sh-script-"))
		    (stdin-file (org-babel-temp-file "sh-stdin-"))
		    (padline (not (string= "no" (cdr (assq :padline params))))))
		(with-temp-file script-file
		  (when shebang (insert shebang "\n"))
		  (when padline (insert "\n"))
		  (insert body))
		(set-file-modes script-file #o755)
		(with-temp-file stdin-file (insert (or stdin "")))
		(with-temp-buffer
		  (call-process-shell-command
		   (concat (if shebang script-file
			     (format "%s %s" shell-file-name script-file))
			   (and cmdline (concat " " cmdline)))
		   stdin-file
		   (current-buffer))
		  (buffer-string))))
	     (session			; session evaluation
	      ;; (map-put params :file file-to-write-progress) ;; TODO htis should happen in one place
	      (mapconcat
	       #'org-babel-sh-strip-weird-long-prompt
	       (mapcar
		#'org-trim
		(butlast
		 (org-babel-comint-with-output
		     (session org-babel-sh-eoe-output t body)
		   (dolist (line (append (split-string (org-trim body) "\n")
					 (list org-babel-sh-eoe-indicator)))
		     (insert line)
		     (comint-send-input nil t)
		     (while (save-excursion
			      (goto-char comint-last-input-end)
			      (not (re-search-forward
				    comint-prompt-regexp nil t)))
		       (accept-process-output
			(get-buffer-process (current-buffer))))))
		 2))
	       "\n"))
	     ;; External shell script, with or without a predefined
	     ;; shebang.
	     ((org-string-nw-p shebang)
	      ;; (map-put params :file file-to-write-progress) ;; TODO htis should happen in one place

	      (let ((script-file (org-babel-temp-file "sh-script-"))
		    (padline (not (equal "no" (cdr (assq :padline params))))))
		(with-temp-file script-file
		  (insert shebang "\n")
		  (when padline (insert "\n"))
		  (insert body))
		(set-file-modes script-file #o755)
		(org-babel-eval script-file "")))
	     (t
	      (when (cdr (assq :file params))
		(message "file was found making process")
		(make-process :name (format "proc-%s-%s" (file-name-nondirectory (cdr (assq :file params))) (md5 body))
			      :buffer (format "buf-%s-%s" (file-name-nondirectory (cdr (assq :file params))) (md5 body))
			      :command (list "sh" "-c" (org-trim body))
			      :connection-type 'pipe
			      :filter (apply-partially 'my-pass-it-on-filter (cdr (assq :file params)))))
	      (unless (cdr (assq :file params))
		(org-babel-eval shell-file-name (org-trim body)))
	      ))))
      (unless (cdr (assq :file params)) ;; don't do this if :file exists
	(when results
	  (let ((result-params (cdr (assq :result-params params))))
	    (org-babel-result-cond result-params
	      results
	      (let ((tmp-file (org-babel-temp-file "sh-")))
		(with-temp-file tmp-file (insert results))
		(org-babel-import-elisp-from-file tmp-file))))))
      ))

  (defun org-babel-execute:shell (body params)
    "Execute a block of Shell commands with Babel.
This function is called by `org-babel-execute-src-block'."
    (when (assq :autolog params)
      (map-put params :file (generate-automatic-log-name)))
    (let* ((session (org-babel-sh-initiate-session
		     (cdr (assq :session params))))
	   (stdin (let ((stdin (cdr (assq :stdin params))))
		    (when stdin (org-babel-sh-var-to-string
				 (org-babel-ref-resolve stdin)))))
	   (cmdline (cdr (assq :cmdline params)))
	   (full-body (org-babel-expand-body:generic
		       body params (org-babel-variable-assignments:shell params))))
      (org-babel-reassemble-table
       (org-babel-sh-evaluate session full-body params stdin cmdline)
       (org-babel-pick-name
	(cdr (assq :colname-names params)) (cdr (assq :colnames params)))
       (org-babel-pick-name
	(cdr (assq :rowname-names params)) (cdr (assq :rownames params))))))
  ;; END org babel sh async file log
  )

(use-package orgit
  :defer t
  :ensure t
  ;; Automatically copy orgit link to last commit after commit
  :hook (git-commit-post-finish . orgit-store-after-commit)
  :config
  (defun orgit-store-after-commit ()
    "Store orgit-link for latest commit after commit message editor is finished."
    (let* ((repo (abbreviate-file-name default-directory))
	   (rev (magit-git-string "rev-parse" "HEAD"))
	   (link (format "orgit-rev:%s::%s" repo rev))
	   (summary (substring-no-properties (magit-format-rev-summary rev)))
	   (desc (format "%s (%s)" summary repo)))
      (push (list link desc) org-stored-links))))

(use-package general
  :ensure t
  :config
  (general-evil-setup)
  (general-imap "j"
    (general-key-dispatch 'self-insert-command
      :timeout 0.25
      ;; TODO make this work so jj writes the file when I enter normal mode
      ;; "j" '(my-write-then-normal-state)
      "f" 'evil-normal-state
      ))
  (general-create-definer leader-define :prefix "SPC" :states 'normal)
  (general-create-definer local-define :prefix "SPC m" :states 'normal)

  (general-unbind 'org-agenda-mode-map
    "SPC")

  (general-unbind 'comint-mode-map
    "C-d")

  (general-create-definer my-leader-def
    :prefix "SPC")

  (my-leader-def
    :states '(normal visual emacs motion)
    :prefix "SPC"
    :keymaps 'override
    :non-normal-prefix "M-SPC"
    "u"   '(universal-argument :which-key "universal-argument")
    "/"   '(helm-projectile-rg :which-key "ripgrep")
    "TAB" '(switch-to-prev-buffer :which-key "previous buffer")
    "SPC" '(helm-M-x :which-key "M-x")
    "TF" '(spacemacs/toggle-frame-fullscreen-non-native :which-key "Full Screen")
    "pf"  '(helm-projectile-find-file :which-key "find files")
    "pF"  '(helm-projectile-find-file-dwim :which-key "find files dwim")
    "jc"  '(avy-goto-char :which-key "Jump To Char")
    "jj"  '(avy-goto-char-timer :which-key "Jump To Char")
    "jl"  '(avy-goto-line :which-key "Jump To line")
    "pp"  '(helm-projectile-switch-project :which-key "switch project")
    "pb"  '(helm-projectile-switch-to-buffer :which-key "switch buffer")
    "pr"  '(helm-show-kill-ring :which-key "show kill ring")

    ;; applications
    "ad"  '(dired :which-key "open dired")
    "oo"  '(org-agenda :which-key "open org agenda")
    "oa"  '(org-agenda-list :which-key "open org agenda list")
    "ol"  '(org-store-link :which-key "store org link")
    "or"  '(helm-org-rifle :which-key "helm org rfile")

    "cc"  '(helm-org-capture-templates :which-key "org-capture")

    ;; magit
    "gs" '(magit-status :which-key "magit status")
    "gt" '(magit-log-trace-definition :which-key "magit trace definition")
    "gl" '(magit-log-popup :which-key "magit log popup")
    "gf" '(magit-file-popup :which-key "magit file popup")
    "gb" '(magit-blame :which-key "magit blame")
    ;; help
    "hdm" '(describe-mode :which-mode "describe mode")
    ;; TODO might need to move these into helpful use-package :config
    "hdk" '(helpful-key :which-key "describe key")
    "hdv" '(helpful-variable :which-key "describe variable")
    "hdf" '(helpful-callable :which-key "describe function")
    "hdd" '(helm-apropos :which-key "apropos at point")
    ;; Buffers
    "bb"  '(helm-mini :which-key "buffers list")
    ;; "bb"  '(helm-persp-buffers :which-key "perspective buffers list")
    "bs"  '(my-switch-to-scratch-buffer :which-key "scratch buffer")
    ;; "bs"  '((switch-to-buffer "*scratch*") :which-key "scratch buffer")
    "bd"  '(spacemacs/kill-this-buffer :which-key "kill-this-buffer")
    ;; Search
    "ss"  '(helm-swoop :which-key "helm-swoop")
    "sS"  '(spacemacs/helm-swoop-region-or-symbol :which-key "helm-swoop-region-or-symbol")
    ;; Window
    ;; TODO install winum (https://github.com/deb0ch/emacs-winum) and use emacs keybindings
    ;; so I can navigate with SPC N
    "wl"  '(evil-window-move-far-right :which-key "move right")
    "wd"  '(delete-window :which-key "delete window")
    "wh"  '(evil-window-move-far-left :which-key "move left")
    "wk"  '(evil-window-move-very-top :which-key "move up")
    "wj"  '(evil-window-move-very-bottom :which-key "move bottom")
    "wm"  '(toggle-maximize-buffer :which-key "maximize buffer")
    "w/"  '(split-window-right :which-key "split right")
    "0" '(winum-select-window-0 :which-key "window 0")
    "1" '(winum-select-window-1 :which-key "window 1")
    "2" '(winum-select-window-2 :which-key "window 2")
    "3" '(winum-select-window-3 :which-key "window 3")
    "4" '(winum-select-window-4 :which-key "window 4")
    "5" '(winum-select-window-5 :which-key "window 5")
    "6" '(winum-select-window-6 :which-key "window 6")
    "7" '(winum-select-window-7 :which-key "window 7")
    "8" '(winum-select-window-8 :which-key "window 8")
    "9" '(winum-select-window-8 :which-key "window 9")
    "w-"  '(split-window-below :which-key "split bottom")
    "wx"  '(delete-window :which-key "delete window")
    "l"  '(persp-switch :which-key "switch perspective")
    "qz"  '(delete-frame :which-key "delete frame")
    "qq"  '(kill-emacs :which-key "quit")
    ;; winner
    "wu"  '(winner-undo :which-key "winner undo")
    "wr"  '(delete-window :which-key "winner redo")
    ;; NeoTree
    "ft"  '(neotree-toggle :which-key "toggle neotree")
    ;; find files
    "ff"  '(helm-find-files :which-key "find files")
    ;; Others
    "at"  '(shell :which-key "open terminal")
    "ae"  '(eshell :which-key "open eshell")
    "cC" '(compile :which-key "compile")
    "cl" '(comment-line :which-key "comment line")
    "fed" '(find-dotfile :which-key "go to init.el")
    "tl" '(toggle-truncate-lines :which-key "truncate lines")
    ;; ehh not sure about this but okay
    "tw" '(whitespace-mode :which-key "show whitespace")
    ;; global org
    "ocj"  '(org-clock-goto :which-key "jump to current clock")
    "aoki"  '(org-clock-in-last :which-key "clock in last task")
    ;; misc
    "so" '(my-helm-stackoverflow-lookup :which-key "search stack overflow")
    )
  (general-define-key
   "M-x" 'helm-M-x)
  (general-evil-define-key 'normal emacs-lisp-mode-map
    :prefix ","
    "ef" 'eval-defun :which-key "eval defun"
    "eb" 'eval-buffer :which-key "eval buffer"
    "er" 'eval-region :which-key "eval region"
    )


  (leader-define
    ;; Code
    "cl" 'comment-line
    "wm"  '(toggle-maximize-buffer :which-key "maximize buffer")
    ;; Quit
    "qq" 'save-buffers-kill-emacs
    )
  (general-evil-define-key 'normal emacs-lisp-mode-map
    :prefix ","
    "ef" 'eval-defun :which-key "eval defun"
    "eb" 'eval-buffer :which-key "eval buffer"
    "er" 'eval-region :which-key "eval region"
    )

  (general-evil-define-key 'normal org-mode-map
    "RET" 'org-open-at-point :which-key "org open at point")

  (general-evil-define-key 'normal org-mode-map
    :prefix ","

    "ds" 'org-schedule :which-key "schedule"
    "dd" 'org-deadline :which-key "schedule"

    ;;
    ;; "C-c C-c" 'codygman/org-ctrl-c-and-go-to-result :which-key "execute code block and go to result"

    "ci" 'org-clock-in :which-key "clock in"
    "co" 'org-clock-out :which-key "clock out"
    "cc" 'org-clock-cancel :which-key "clock cancel"
    "tt" 'org-todo :which-key "org todo"

    ;; magithub
    ;; browse file on github
    "gBf" 'magithub-browse-file :which-key "magithub browse file"

    "ts" 'org-download-screenshot :which-key "org download screenshot"

    ;; insert
    "iB" 'org-insert-structure-template :which-key "insert org block"
    "ib" 'insert-previous-src-block-below :which-key "insert previous org src block"
    "tc" 'org-table-create :which-key "org table create"
    "it" 'org-set-tags-command :which-key "org set tags"
    "is" 'my-org-insert-subheading :which-key "org insert subheading"
    "ic" 'yas-insert-snippet :which-key "insert yasnippet code"
    "iS" 'my-org-insert-subheading-then-normal :which-key "org insert subhead then normal"
    "il" 'codygman/pad-then-insert-link :which-key "org insert link"
    "ip" 'org-set-property :which-key "org set property"

    "sh" 'org-promote-subtree :which-key "promote subtree-left"
    "sj" 'org-move-subtree-down :which-key "subtree-down"
    "sk" 'org-move-subtree-up :which-key "subtree-up"
    "sl" 'org-demote-subtree :which-key "demote subtree-right"
    "sn" 'org-narrow-to-subtree :which-key "org narrow"
    "sN" 'widen :which-key "org widen"
    "sb" 'org-tree-to-indirect-buffer :which-key "org tree to indirect buffer"

    "#" 'org-update-statistics-cookies :which-key "org-update-statistics-cookies"
    )

  )

(use-package winum
  :defer t
  :ensure t
  :init (winum-mode))

(defalias 'yes-or-no-p 'y-or-n-p)

(defun toggle-maximize-buffer () "Maximize buffer"
       (interactive)
       (if (= 1 (length (window-list)))
	   (jump-to-register '_)
	 (progn
	   (window-configuration-to-register '_)
	   (delete-other-windows))))

(defun codygman/pad-then-insert-link ()
  ;; TODO this is too naieve and messes up modifying links (see heading I think I made)
  (interactive)
  (evil-insert 1)
  (insert "  ")
  (evil-normal-state)
  (call-interactively 'org-insert-link))

(use-package helm-swoop
  :ensure t
  :init
  (setq helm-swoop-split-with-multiple-windows t
	helm-swoop-split-direction 'split-window-vertically
	helm-swoop-speed-or-color t
	helm-swoop-split-window-function 'helm-default-display-buffer
	helm-swoop-pre-input-function (lambda () "")))

;; always follow symlinks and DONT PROMPT ME
(setq vc-follow-symlinks t)

(use-package helm
  :ensure t
  :init
  (setq helm-M-x-fuzzy-match t
	helm-mode-fuzzy-match t
	helm-buffers-fuzzy-matching t
	helm-recentf-fuzzy-match t
	helm-locate-fuzzy-match t
	helm-semantic-fuzzy-match t
	helm-imenu-fuzzy-match t
	helm-completion-in-region-fuzzy-match t
	helm-candidate-number-list 80
	;; helm-split-window-in-side-p t
	helm-move-to-line-cycle-in-source t
	helm-echo-input-in-header-line t
	helm-autoresize-max-height 0
	helm-autoresize-min-height 20
	helm-always-two-windows t
	)
  :config
  (use-package helm-flx
    :ensure t)
  (use-package helm-fuzzier
    :ensure t)
  (use-package helm-rg
    :ensure t)
  (helm-mode 1)
  (helm-flx-mode 1)
  (helm-fuzzier-mode 1)
  :bind (:map helm-map
	      ("<tab>" . helm-execute-persistent-action)
	      ("C-h" . helm-find-files-up-one-level)
	      ("<backtab>" . helm-find-files-up-one-level)
	      ("C-z" . helm-select-action)
	      )
  )

(defun spacemacs/toggle-frame-fullscreen-non-native ()
  "Toggle full screen non-natively. Uses the `fullboth' frame paramerter
   rather than `fullscreen'. Useful to fullscreen on OSX w/o animations."
  (interactive)
  (modify-frame-parameters
   nil
   `((maximized
      . ,(unless (memq (frame-parameter nil 'fullscreen) '(fullscreen fullboth))
	   (frame-parameter nil 'fullscreen)))
     (fullscreen
      . ,(if (memq (frame-parameter nil 'fullscreen) '(fullscreen fullboth))
	     (if (eq (frame-parameter nil 'maximized) 'maximized)
		 'maximized)
	   'fullboth)))))

(use-package haskell-mode
  :ensure t
  :mode "\\.hs\\'"
  :commands haskell-mode
  :config
  (setq haskell-mode-stylish-haskell-path "brittany")
  (setq haskell-stylish-on-save t)

  (add-hook 'haskell-mode-hook 'haskell-indentation-mode)
  ;; (add-hook 'haskell-mode-hook 'interactive-haskell-mode)
  )

(use-package restclient :ensure t :defer t)
(use-package ob-restclient :ensure t :after org)
(use-package ob-async :ensure t :after org)

(with-eval-after-load "magit-diff"
  ;; Swap the meanings of RET and C-RET on diff hunks.
  ;; Note that the default RET bindings are [remap magit-visit-thing]
  ;; in the original keymaps, but I am only concerned with RET here.
  ;; Note also that in a terminal, C-RET sends C-j.
  ;; Using the same key formats here as magit-diff.el
  (define-key magit-file-section-map [return] 'magit-diff-visit-file-worktree)
  (define-key magit-file-section-map [C-return] 'magit-diff-visit-file)
  (define-key magit-file-section-map (kbd "C-j") 'magit-diff-visit-file)
  (define-key magit-hunk-section-map [return] 'magit-diff-visit-file-worktree)
  (define-key magit-hunk-section-map [C-return] 'magit-diff-visit-file)
  (define-key magit-hunk-section-map (kbd "C-j") 'magit-diff-visit-file))

(use-package magit
  :ensure t
  :defer t
  :config
  (defun my-truncate-lines ()
    (setq truncate-lines t))

  (add-hook 'magit-diff-mode-hook 'my-truncate-lines)
  )

(use-package evil-magit :ensure t :after (evil magit))

(use-package projectile
  :ensure t
  :config
)

;; Helm Projectile
(use-package helm-projectile
  :ensure t
  :init
  (setq helm-projectile-fuzzy-match t)
  :config
  (helm-projectile-on))

(use-package which-key
  :ensure t
  :init
  (setq which-key-separator " ")
  (setq which-key-prefix-prefix "+")
  :config
  (which-key-mode))

(use-package avy
  :ensure t
  :config
  (avy-setup-default))

(use-package helm-org-rifle
  :ensure t
  :after (helm org)
  )

(defun spacemacs/helm-swoop-region-or-symbol ()
  "Call `helm-swoop' with default input."
  (interactive)
  (let ((helm-swoop-pre-input-function
	 (lambda ()
	   (if (region-active-p)
	       (buffer-substring-no-properties (region-beginning)
					       (region-end))
	     (let ((thing (thing-at-point 'symbol t)))
	       (if thing thing ""))))))
    (call-interactively 'helm-swoop)))

;; put this in general block maybe?
(defun spacemacs/kill-this-buffer (&optional arg)
  "Kill the current buffer.
If the universal prefix argument is used then kill also the window."
  (interactive "P")
  (if (window-minibuffer-p)
      (abort-recursive-edit)
    (if (equal '(4) arg)
	(kill-buffer-and-window)
      (kill-buffer))))

(defun my-switch-to-scratch-buffer ()
  (switch-to-buffer (get-buffer-create "*scratch*")))

(use-package helpful
  :ensure t
  :config
  (global-set-key (kbd "C-h f") #'helpful-callable)
  (global-set-key (kbd "C-h v") #'helpful-variable)
  (global-set-key (kbd "C-h k") #'helpful-key)
  (advice-add 'helpful-update :after #'elisp-demos-advice-helpful-update)
  )

(use-package doom-themes
  :ensure t
  :config
  (load-theme 'doom-one t))

(use-package ob-mongo :ensure t)

(with-eval-after-load "ob-shell"

  (defun my-pass-it-on-filter (filePath proc str)
    "Process each line produced by PROC in STR."
    (interactive)
    (when (buffer-live-p (process-buffer proc))
      (with-current-buffer (process-buffer proc)
	(insert str)
	(goto-char (point-min))
	(while (progn (skip-chars-forward "^\n")
		      (not (eobp)))
	  (ignore-errors
	    (let ((result (delete-and-extract-region (point-min) (point))))
	      (delete-char 1)
	      ;; (message (format "writing result '%s' w/newline to %s" result filePath))
	      (when (not (file-exists-p filePath))
		(write-region "" nil filePath))
	      (write-region (concat result "\n") nil filePath 'append)
	      result))))))

  (defun get-parent-heading-title ()
    (ignore-errors
      (save-excursion
	(org-evil-motion-up-heading)
	(org-element-property :title (org-element-at-point)))))

  (defun get-grandparent-heading-title ()
    (ignore-errors
      (save-excursion
	(org-evil-motion-up-heading)
	(org-evil-motion-up-heading)
	(org-element-property :title (org-element-at-point)))
      ))

  (defun get-great-grandparent-heading-title ()
    (ignore-errors
      (save-excursion
	(org-evil-motion-up-heading)
	(org-evil-motion-up-heading)
	(org-evil-motion-up-heading)
	(org-element-property :title (org-element-at-point)))
      ))

  (defun cleanup-dir-name (dir)
    (replace-regexp-in-string " " "-" dir))

  (defun my-create-non-existent-directory ()
    (let ((parent-directory (file-name-directory buffer-file-name)))
      (when (not (file-exists-p parent-directory))
	(make-directory parent-directory t))))

  (defun generate-automatic-log-name ()
    ;; TODO make this take the parent org element and use its heading text in this log name
    (let* ((time-with-millis (format-time-string "%H.%M.%S.%3N"))
	   (year-month-day (format-time-string "%Y-%m-%d"))
	   (parent-element-title (get-parent-heading-title))
	   (grandparent-element-title (get-grandparent-heading-title))
	   (great-grandparent-element-title (get-great-grandparent-heading-title))
	   (descriptive-string (if (> 20 (length parent-element-title)) (format "%s_%s" grandparent-element-title parent-element-title) parent-element-title))
	   (descriptive-string-2 (if (> 20 (length descriptive-string)) (format "%s_%s" great-grandparent-element-title descriptive-string) descriptive-string))
	   (descriptive-string-safe (cleanup-dir-name descriptive-string-2))
	   (file-path (format "/Users/codygman/console/%s/%s.%s.%s.log" year-month-day descriptive-string-safe year-month-day time-with-millis))
	   (directory-path (file-name-directory file-path))
	   )
      ;; create directory if it doesn't exist
      (when (not (file-exists-p directory-path))
	(make-directory directory-path t))
      ;; use log extension since I know those links will open in emacs
      file-path))

  (defun current-line-empty-p ()
    (save-excursion
      (beginning-of-line)
      (looking-at "[[:space:]]*$")))

  (defun insert-previous-src-block-below ()
    (interactive)
    (save-excursion
      (org-evil-motion-backward-block-begin)
      ;; if we aren't at a source block or at top of file keep going to previous block
      (while (and
	      (not (org-element-property :language (org-element-at-point)))
	      (> (point) (point-min))) ;; our point is more than beginning of buffer
	(org-evil-motion-backward-block-begin)
	)
      (org-cycle)
      (org-kill-line)
      (evil-paste-after 1))
    ;; (evil-append-line 1)
    (if (current-line-empty-p)	
	(call-interactively 'evil-paste-after)
      (progn (evil-open-below 1)
	     (call-interactively 'evil-paste-before)))
    (evil-normal-state)
    (evil-previous-line)
    (evil-first-non-blank))

  (defun directory-to-write-progress (params)
    ;; if params has :log then autogenerate based on date, time, and immediate parent heading text
    (cond
     ((assq :autolog params)
      (message "autolog present, generating automatic log path and populating :file")
      (generate-automatic-log-name))
     ((cdr (assq :file params))
      (message "no autolog just returning :file specified")
      (cdr (assq :file params)))
     (t
      (message "no :file or :autolog returning nil")
      nil)))

  (defun org-babel-sh-evaluate (session body &optional params stdin cmdline)
    "Pass BODY to the Shell process in BUFFER.
If RESULT-TYPE equals `output' then return a list of the outputs
of the statements in BODY, if RESULT-TYPE equals `value' then
return the value of the last statement in BODY."
    (let* ((shebang (cdr (assq :shebang params)))
	   (results
	    (cond
	     ((or stdin cmdline)	       ; external shell script w/STDIN
	      ;; (map-put params :file file-to-write-progress) ;; TODO htis should happen in one place
	      (let ((script-file (org-babel-temp-file "sh-script-"))
		    (stdin-file (org-babel-temp-file "sh-stdin-"))
		    (padline (not (string= "no" (cdr (assq :padline params))))))
		(with-temp-file script-file
		  (when shebang (insert shebang "\n"))
		  (when padline (insert "\n"))
		  (insert body))
		(set-file-modes script-file #o755)
		(with-temp-file stdin-file (insert (or stdin "")))
		(with-temp-buffer
		  (call-process-shell-command
		   (concat (if shebang script-file
			     (format "%s %s" shell-file-name script-file))
			   (and cmdline (concat " " cmdline)))
		   stdin-file
		   (current-buffer))
		  (buffer-string))))
	     (session			; session evaluation
	      ;; (map-put params :file file-to-write-progress) ;; TODO htis should happen in one place
	      (mapconcat
	       #'org-babel-sh-strip-weird-long-prompt
	       (mapcar
		#'org-trim
		(butlast
		 (org-babel-comint-with-output
		     (session org-babel-sh-eoe-output t body)
		   (dolist (line (append (split-string (org-trim body) "\n")
					 (list org-babel-sh-eoe-indicator)))
		     (insert line)
		     (comint-send-input nil t)
		     (while (save-excursion
			      (goto-char comint-last-input-end)
			      (not (re-search-forward
				    comint-prompt-regexp nil t)))
		       (accept-process-output
			(get-buffer-process (current-buffer))))))
		 2))
	       "\n"))
	     ;; External shell script, with or without a predefined
	     ;; shebang.
	     ((org-string-nw-p shebang)
	      ;; (map-put params :file file-to-write-progress) ;; TODO htis should happen in one place

	      (let ((script-file (org-babel-temp-file "sh-script-"))
		    (padline (not (equal "no" (cdr (assq :padline params))))))
		(with-temp-file script-file
		  (insert shebang "\n")
		  (when padline (insert "\n"))
		  (insert body))
		(set-file-modes script-file #o755)
		(org-babel-eval script-file "")))
	     (t
	      (when (cdr (assq :file params))
		(message "file was found making process")
		(make-process :name (format "proc-%s-%s" (file-name-nondirectory (cdr (assq :file params))) (md5 body))
			      :buffer (format "buf-%s-%s" (file-name-nondirectory (cdr (assq :file params))) (md5 body))
			      :command (list "sh" "-c" (org-trim body))
			      :connection-type 'pipe
			      :filter (apply-partially 'my-pass-it-on-filter (cdr (assq :file params)))))
	      (unless (cdr (assq :file params))
		(org-babel-eval shell-file-name (org-trim body)))
	      ))))
      (unless (cdr (assq :file params)) ;; don't do this if :file exists
	(when results
	  (let ((result-params (cdr (assq :result-params params))))
	    (org-babel-result-cond result-params
	      results
	      (let ((tmp-file (org-babel-temp-file "sh-")))
		(with-temp-file tmp-file (insert results))
		(org-babel-import-elisp-from-file tmp-file))))))
      ))

  (defun org-babel-execute:shell (body params)
    "Execute a block of Shell commands with Babel.
This function is called by `org-babel-execute-src-block'."
    (when (assq :autolog params)
      (map-put params :file (generate-automatic-log-name)))
    (let* ((session (org-babel-sh-initiate-session
		     (cdr (assq :session params))))
	   (stdin (let ((stdin (cdr (assq :stdin params))))
		    (when stdin (org-babel-sh-var-to-string
				 (org-babel-ref-resolve stdin)))))
	   (cmdline (cdr (assq :cmdline params)))
	   (full-body (org-babel-expand-body:generic
		       body params (org-babel-variable-assignments:shell params))))
      (org-babel-reassemble-table
       (org-babel-sh-evaluate session full-body params stdin cmdline)
       (org-babel-pick-name
	(cdr (assq :colname-names params)) (cdr (assq :colnames params)))
       (org-babel-pick-name
	(cdr (assq :rowname-names params)) (cdr (assq :rownames params))))))
  )

(with-eval-after-load "ob-mongo"
  (defun ob-mongo--make-command (params)
    (if (assq :connString params)
	;; if connString is present
	(let ((connString (cdr (assq :connString params)))
	      (username (cdr (assq :username params)))
	      (password (cdr (assq :password params))))
	  (message connString)
	  (format "mongo --quiet %s" connString))
      ;; if connString is not present
      (let ((pdefs `((:mongoexec ,ob-mongo:default-mongo-executable)
		     (quiet "--quiet")
		     (:host , ob-mongo:default-host "--host")
		     (:port ,ob-mongo:default-port "--port")
		     (:password ,ob-mongo:default-password "--password")
		     (:user ,ob-mongo:default-user "--username")
		     (:db ,ob-mongo:default-db))))
	(mapconcat (lambda (pdef)
		     (let ((opt (or (nth 2 pdef) ""))
			   (val (or (cdr (assoc (car pdef) params))
				    (nth 1 pdef))))
		       (cond ((not opt) (format "%s" val))
			     (val (format "%s %s" opt val))
			     (t ""))))
		   pdefs " "))))

  (defun org-babel-execute:mongo (body params)
    "org-babel mongo hook."
    (unless (assoc :db params)
      (user-error "The required parameter :db is missing."))
    (let* ((command (ob-mongo--make-command params))
	   (result (org-babel-eval command body)) ;; TODO figure out why org-babel-eval doesn't work and throws peculiar:
	   )
      (message (concat "xo command: " command))
      (message (concat "result: " result))
      (string-join
       (seq-filter
	(lambda (line) (not (string-match-p "I NETWORK" line)))
	(split-string result (regexp-quote "\n")))
       "\n")))
  )

(with-eval-after-load "ob-restclient"
  (defun restclient-http-parse-current-and-do (func &rest args) ;
    (save-excursion
      (goto-char (restclient-current-min))
      (when (re-search-forward restclient-method-url-regexp (point-max) t)
	(let ((method (match-string-no-properties 1))
	      (url (match-string-no-properties 2))
	      (vars (restclient-find-vars-before-point))
	      (headers '()))
	  (forward-line)
	  (while (cond
		  ((and (looking-at restclient-header-regexp) (not (looking-at restclient-empty-line-regexp)))
		   (setq headers (cons (restclient-replace-all-in-header vars (restclient-make-header)) headers)))
		  ((looking-at restclient-use-var-regexp)
		   (setq headers (append headers (restclient-parse-headers (restclient-replace-all-in-string vars (match-string 1)))))))
	    (forward-line))
	  (when (looking-at restclient-empty-line-regexp)
	    (forward-line))
	  (let* ((cmax (restclient-current-max))
		 (entity (restclient-parse-body (buffer-substring (min (point) cmax) cmax) vars))
		 (url (restclient-replace-all-in-string vars (string-trim url))))
	    (apply func method url headers entity args))))))
  )


(use-package docker-tramp
  :defer t
  :ensure t)

(use-package evil-collection
  :after evil
  :ensure t
  :config
  (evil-collection-init))
