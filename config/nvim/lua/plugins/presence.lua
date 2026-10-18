local idle_messages = {
  "procrastination-maxxing",
  "Getting job rejection emails",
  "what am I doing in life man",
  "Ayo the pizza here",
  "The lion is greatly concerned",
  "many such cases",
  "it's so over",
  "we are so back",
  "chat is this real",
  "bro thinks he's locked in",
  "the fog is coming",
  "I have no enemies",
  "this edible ain't hitting",
  "standing on business, allegedly",
  "locked out of the main quest",
  "cooked, fried, sauteed even",
  "looking for who asked",
  "the council will decide my fate",
}

local idle_timeout = 5 * 60 * 1000

return {
  {
    "andweeb/presence.nvim",
    lazy = false,
    cond = function() return #vim.api.nvim_list_uis() > 0 end,
    config = function()
      math.randomseed(os.time())
      local is_idle = false
      local idle_message = idle_messages[1]
      local idle_timer = assert(vim.uv.new_timer())

      local function current_buffer()
        local name = vim.api.nvim_buf_get_name(0)
        if name ~= "" then return name end
      end

      local function update_presence(should_debounce)
        local ok, presence = pcall(require, "presence")
        local buffer = current_buffer()
        if ok and buffer then presence:update(buffer, should_debounce or false) end
      end

      local function pick_idle_message()
        idle_message = idle_messages[math.random(#idle_messages)]
      end

      local function reset_idle_timer()
        idle_timer:stop()
        idle_timer:start(
          idle_timeout,
          0,
          vim.schedule_wrap(function()
            is_idle = true
            pick_idle_message()
            update_presence(false)
          end)
        )
      end

      local function wake()
        if is_idle then
          is_idle = false
          update_presence(false)
        else
          update_presence(true)
        end
        reset_idle_timer()
      end

      require("presence").setup {
        auto_update = true,
        debounce_timeout = 1,
        main_image = "neovim",
        neovim_image_text = "Neovim",
        enable_line_number = true,
        buttons = false,
        show_time = true,
        editing_text = function(filename)
          if is_idle then return idle_message end
          return ("Editing %s"):format(filename)
        end,
        reading_text = function(filename)
          if is_idle then return idle_message end
          return ("Reading %s"):format(filename)
        end,
        workspace_text = function(project_name)
          if is_idle then return idle_message end
          return ("Working on %s"):format(project_name)
        end,
        line_number_text = function(line, line_count)
          if is_idle then return "Idle" end
          return ("Line %s out of %s"):format(line, line_count)
        end,
      }

      vim.api.nvim_create_autocmd({
        "BufEnter",
        "CursorMoved",
        "CursorMovedI",
        "FocusGained",
        "InsertEnter",
        "TextChanged",
        "TextChangedI",
      }, {
        group = vim.api.nvim_create_augroup("presence_idle", { clear = true }),
        callback = wake,
      })

      reset_idle_timer()
      vim.schedule(update_presence)
    end,
  },
}
