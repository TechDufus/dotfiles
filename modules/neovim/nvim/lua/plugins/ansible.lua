-- nvim-ansible: Smart Ansible file detection based on directory structure
-- Detects Ansible files by path patterns (tasks/, defaults/, handlers/, playbooks/, etc.)
-- rather than forcing ALL yaml files to be Ansible
return {
  'mfussenegger/nvim-ansible',
  -- No lazy loading - ftdetect must run at startup for filetype detection
  lazy = false,
  init = function()
    -- Additional path-based patterns for Ansible detection
    vim.filetype.add({
      pattern = {
        -- Requirements files for ansible-galaxy
        [".*/requirements%.yml"] = "yaml.ansible",
        [".*/requirements/.*%.yml"] = "yaml.ansible",
        -- Meta files in roles
        [".*/meta/main%.ya?ml"] = "yaml.ansible",
        -- Vars directories
        [".*/vars/.*%.ya?ml"] = "yaml.ansible",
      },
    })

    -- Content-based detection for Ansible playbooks and tasks
    -- Runs after buffer is read, upgrades yaml -> yaml.ansible if Ansible patterns found
    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
      pattern = { "*.yml", "*.yaml" },
      callback = function()
        -- Skip if already detected as ansible by nvim-ansible's path patterns
        if vim.bo.filetype == "yaml.ansible" then
          return
        end
        -- Only check yaml files
        if vim.bo.filetype ~= "yaml" then
          return
        end

        local lines = vim.api.nvim_buf_get_lines(0, 0, 50, false)
        for _, line in ipairs(lines) do
          -- Ansible playbooks: "hosts:" key
          if line:match("^%s*hosts:") or line:match("^%s*-%s*hosts:") then
            vim.bo.filetype = "yaml.ansible"
            return
          end
          -- Ansible modules: ansible.builtin.*, ansible.posix.*, etc.
          if line:match("ansible%.builtin%.") or line:match("ansible%.posix%.") then
            vim.bo.filetype = "yaml.ansible"
            return
          end
          -- Common Ansible keywords
          if line:match("^%s+become:") or line:match("^%s+notify:") or line:match("^%s+register:") or line:match("^%s+loop_control:") or line:match("^%s+failed_when:") or line:match("^%s+changed_when:") then
            vim.bo.filetype = "yaml.ansible"
            return
          end
        end
      end,
    })

    -- Add keymap for running playbooks when in ansible files
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'yaml.ansible',
      callback = function()
        vim.keymap.set('n', '<leader>ta', function()
          require('ansible').run()
        end, { buffer = true, desc = 'Run Ansible playbook/role' })
      end,
    })
  end,
}
