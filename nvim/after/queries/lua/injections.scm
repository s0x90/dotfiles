; extends

; Inject luadoc parser into --- annotation comments (e.g. ---@type, ---@field, ---@param)
(comment
  content: (_) @injection.content
  (#lua-match? @injection.content "^[-][%s]*[@|]")
  (#set! injection.language "luadoc")
  (#offset! @injection.content 0 1 0 0))
