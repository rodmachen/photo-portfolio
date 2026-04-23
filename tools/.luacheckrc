std = 'lua54'
globals = { 'import', '_PLUGIN', 'LOC', 'pairs', 'ipairs' }
read_globals = {
  -- LR SDK globals if any are referenced as globals; most arrive via `import`
}
exclude_files = { '.luarocks/' }
ignore = {
  '212', -- unused argument (LR callbacks)
}
