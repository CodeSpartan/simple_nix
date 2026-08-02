-- Telescope configuration.

local actions = require "telescope.actions"

return {
  defaults = {
    mappings = {
      -- Telescope records every prompt to stdpath("data")/telescope_history but
      -- binds no keys to walk it. The list is shared across pickers, so cycling
      -- inside live grep also surfaces find_files prompts.
      i = {
        ["<C-Up>"] = actions.cycle_history_prev,
        ["<C-Down>"] = actions.cycle_history_next,
      },
      n = {
        ["<C-Up>"] = actions.cycle_history_prev,
        ["<C-Down>"] = actions.cycle_history_next,
      },
    },
  },

  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
  },
}
