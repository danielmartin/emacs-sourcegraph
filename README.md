# sourcegraph.el

Emacs Lisp library that adds Sourcegraph integration to Emacs.

## Installation

Download sourcegraph.el and add it to `load-path`. Load the library
from your initialization file with the following code:

```elisp
(require 'sourcegraph)
```

## Configuration

By default, the library points the public Sourcegraph instance at
https://sourcegraph.com, which indexes a lot of public open source
code. You can configure the `sourcegraph-url` variable to point to the
URL of your Sourcegraph instance instead:

```elisp
(setq sourcegraph-url "https://sourcegraph_URL_or_IP")
```

To enable the `sourcegraph-mode` minor mode in a particular buffer do
`M-x sourcegraph-mode`. To enable it for every programming language
mode:

```elisp
(add-hook 'prog-mode-hook 'sourcegraph-mode)
```

## Features

This package offers the following features:

- `sourcegraph-open-in-browser`: Opens the current line/column in
  Sourcegraph.

- `sourcegraph-search`: Performs a search query in Sourcegraph.

## Future Work

There are some plans to expand the functionality of this program:

- Implement an Xref backend that can provide code intelligence using
  Sourcegraph. For that, we probably need to investigate if
  Sourcegraph provides an appropriate API. Or contribute one upstream
  if not.

- Org-babel integration. A Sourcegraph link in a literate program
  would expand into the actual source code when the document is
  exported. This feature is inspired by the "live snippet"
  functionality in gdoc3 described in page 358 of the "Software
  Engineering at Google" book.
