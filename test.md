# Reader Mode Test

This is a test of **reader mode** in Neovim. It should render with a centered narrow column, word wrapping, and styled markdown.

## Features

- Centered narrow column via `zen-mode`
- In-buffer markdown rendering via `render-markdown`
- Inline images via `image.nvim`

## Text Formatting

This is **bold**, this is *italic*, and this is `inline code`.

> This is a blockquote. It should be visually distinct.

## A Table

| Plugin | Purpose |
|---|---|
| zen-mode | Centered layout |
| render-markdown | In-buffer rendering |
| image.nvim | Inline images |

## Inline Image

![A sleepy cat](https://upload.wikimedia.org/wikipedia/commons/thumb/4/48/RedCat_8727.jpg/320px-RedCat_8727.jpg)

## Code Block

```lua
local function hello()
  print("reader mode is working!")
end
```
