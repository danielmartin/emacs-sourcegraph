# sourcegraph.el

Emacs Lisp library that adds Sourcegraph integration to Emacs.

## Installation

Download sourcegraph.el and add it to `load-path`. Load the library
from your initialization file with the following code:

```elisp
(require 'sourcegraph)
```

## Configuration

For the library to work correctly, you need to configure the
`sourcegraph-url` variable to point to the URL of your Sourcegraph
instance:

```elisp
(setq sourcegraph-url "https://sourcegraph_URL_or_IP")
```

And then enable the `sourcegraph-mode` minor mode, for example, for
every programming language mode:

```elisp
(add-hook 'prog-mode-hook 'sourcegraph-mode)
```

## Features

This package offers the following features:

- `sourcegraph-open-in-browser`: Opens the current line/column in
  Sourcegraph.

- `sourcegraph-search`: Performs a search query in Sourcegraph.
