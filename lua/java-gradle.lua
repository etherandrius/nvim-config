-- Buildship preferences are local editor state. Repair only ignored, untracked
-- version overrides before JDTLS starts; never change build scripts or run Gradle.
local M = {}
local uv = vim.uv
local prepared = {}
local suffix = ".settings/org.eclipse.buildship.core.prefs"

function M.root(filename)
    local dir = vim.fs.dirname(uv.fs_realpath(filename) or vim.fs.normalize(filename))
    local fallback
    while dir do
        if uv.fs_stat(dir .. "/gradlew") or uv.fs_stat(dir .. "/mvnw") then
            return dir
        end
        if uv.fs_stat(dir .. "/settings.gradle") or uv.fs_stat(dir .. "/settings.gradle.kts")
            or uv.fs_stat(dir .. "/pom.xml") then
            fallback = dir
        end
        if uv.fs_stat(dir .. "/.git") then
            return fallback or dir
        end
        if not fallback and (uv.fs_stat(dir .. "/build.gradle") or uv.fs_stat(dir .. "/build.gradle.kts")) then
            fallback = dir
        end
        local parent = vim.fs.dirname(dir)
        if parent == dir then break end
        dir = parent
    end
    return fallback
end

function M.workspace(root)
    return vim.fn.stdpath("cache") .. "/jdtls/" .. vim.fn.sha256(uv.fs_realpath(root) or root)
end

local function read(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()
    return data
end

-- Preserve comments, other settings, line endings and missing final newlines.
function M.rewrite(data, project_dir)
    local lines = vim.split(data, "\n", { plain = true })
    local matches, managed, distribution_line = 0, false, nil
    for i, line in ipairs(lines) do
        if line:match("^connection%.gradle%.distribution=") then
            matches, distribution_line = matches + 1, i
        end
        local version, cr = line:match("^connection%.gradle%.distribution=GRADLE_DISTRIBUTION%(VERSION%(([^()]+)%)%)(\r?)$")
        if version then
            lines[i] = "connection.gradle.distribution=GRADLE_DISTRIBUTION(WRAPPER)" .. cr
            managed = true
        elseif line:match("^connection%.gradle%.distribution=GRADLE_DISTRIBUTION%(WRAPPER%)\r?$") then
            managed = true
        end
    end
    assert(matches <= 1, "Duplicate Gradle distribution entries; repair manually")
    if managed and project_dir ~= nil then
        local dirs = 0
        for i, line in ipairs(lines) do
            if line:match("^connection%.project%.dir=") then
                dirs = dirs + 1
                lines[i] = "connection.project.dir=" .. project_dir .. (line:sub(-1) == "\r" and "\r" or "")
            end
        end
        assert(dirs <= 1, "Duplicate Gradle project directory; repair manually")
        if dirs == 0 then
            local cr = lines[distribution_line]:sub(-1) == "\r" and "\r" or ""
            table.insert(lines, distribution_line + 1, "connection.project.dir=" .. project_dir .. cr)
        end
    end
    return table.concat(lines, "\n")
end

local function write_exclusive(path, data, mode)
    local fd = assert(uv.fs_open(path, "wx", mode or 384))
    local written, err = uv.fs_write(fd, data, 0)
    uv.fs_close(fd)
    assert(written == #data, err or "Incomplete write: " .. path)
end

-- Public for bounded one-off repairs/tests. No caches or notifications here.
function M.repair(root, opts)
    opts = opts or {}
    root = assert(uv.fs_realpath(root), "Missing project root")
    local report = { root = root, inspected = 0, changed = {}, errors = {} }
    if not uv.fs_stat(root .. "/gradlew")
        or not uv.fs_stat(root .. "/gradle/wrapper/gradle-wrapper.properties") then
        return report
    end
    -- Prune dependency/build trees: git ls-files --others alone traverses huge
    -- ignored node_modules directories even with a preference-file pathspec.
    local command = { "find", ".", "(", "-name", ".git", "-o", "-name", "node_modules",
        "-o", "-name", "build", "-o", "-name", ".gradle", "-o", "-name", ".claude",
        "-o", "-name", "dist", "-o", "-name", ".venv", "-o", "-name", ".envs",
        "-o", "-name", ".yarn", ")", "-prune", "-o", "-type", "f", "-path", "*/" .. suffix, "-print0" }
    if vim.fn.executable("fd") == 1 then
        command = { "fd", "--hidden", "--no-ignore", "--type", "f", "--print0" }
        for _, name in ipairs({ ".git", "node_modules", "build", ".gradle", ".claude", "dist", ".venv", ".envs", ".yarn" }) do
            vim.list_extend(command, { "--exclude", name })
        end
        command[#command + 1] = "^org\\.eclipse\\.buildship\\.core\\.prefs$"
    end
    local scan = vim.system(command, { cwd = root }):wait(3000)
    assert(scan.code == 0, "Buildship metadata scan failed/timed out: " .. (scan.stderr or ""))
    if scan.stdout == "" then return report end
    -- check-ignore omits tracked files by default, including force-added metadata.
    local result = vim.system({ "git", "-C", root, "check-ignore", "-z", "--stdin" },
        { stdin = scan.stdout }):wait(3000)
    assert(result.code == 0 or result.code == 1, "Could not verify ignored metadata: " .. (result.stderr or ""))
    for _, relative in ipairs(vim.split(result.stdout, "\0", { plain = true, trimempty = true })) do
        local rel = relative:gsub("^%./", "")
        if rel:sub(-#suffix) == suffix and not rel:match("^%.%./") then
            local path = root .. "/" .. rel
            local stat = uv.fs_lstat(path)
            if stat and stat.type == "file" and uv.fs_realpath(path) == path and M.root(path) == root then
                local ok, err = pcall(function()
                    local before = read(path)
                    local module = vim.fs.dirname(vim.fs.dirname(path))
                    -- Older module-root imports also persist the wrong project dir.
                    -- M.root above excludes nested repositories/independent wrappers.
                    local project_dir = module == root and "" or module:sub(#root + 2):gsub("[^/]+", "..")
                    report.inspected = report.inspected + 1
                    local after = M.rewrite(before, project_dir)
                    if before == after then return end
                    if not report.backup then
                        local base = opts.backup_base or (vim.fn.stdpath("state") .. "/java-gradle-backups")
                        vim.fn.mkdir(base, "p", 448)
                        report.backup = assert(uv.fs_mkdtemp(base .. "/repair-XXXXXX"))
                        write_exclusive(report.backup .. "/root.txt", root .. "\n")
                    end
                    local backup = report.backup .. "/" .. rel
                    vim.fn.mkdir(vim.fs.dirname(backup), "p", 448)
                    write_exclusive(backup, before)
                    assert(read(path) == before, "Preferences changed during repair; retry after stopping JDTLS")
                    local temp = path .. ".nvim-" .. uv.os_getpid() .. "-" .. uv.hrtime()
                    local written, failure = pcall(function()
                        write_exclusive(temp, after, stat.mode % 512)
                        assert(read(path) == before, "Preferences changed during repair; retry after stopping JDTLS")
                        assert(uv.fs_rename(temp, path))
                    end)
                    if not written then
                        uv.fs_unlink(temp)
                        error(failure)
                    end
                    report.changed[#report.changed + 1] = rel
                end)
                if not ok then report.errors[#report.errors + 1] = rel .. ": " .. tostring(err) end
            end
        end
    end
    return report
end

function M.prepare(root)
    root = uv.fs_realpath(root) or root
    if prepared[root] then return end
    prepared[root] = true
    local started = uv.hrtime()
    local ok, report = pcall(M.repair, root)
    local function notify(message, level)
        vim.schedule(function() vim.notify(message, level, { title = "Java / Gradle" }) end)
    end
    if not ok then
        notify("Could not check local Gradle overrides: " .. tostring(report), vim.log.levels.WARN)
        return
    end
    if #report.changed > 0 then
        notify(("Aligned %d local Gradle preferences with the build root and WRAPPER. Backup: %s")
            :format(#report.changed, report.backup), vim.log.levels.INFO)
    end
    if #report.errors > 0 then
        notify("Some Gradle overrides could not be repaired:\n" .. table.concat(report.errors, "\n"), vim.log.levels.WARN)
    end
    if report.inspected >= 30 and (vim.g.java_build_configuration_update or "disabled") == "automatic" then
        notify(("%s has %d imported Gradle projects. Automatic build-file refresh may use substantial CPU/RAM "
            .. "and resolve dependencies; automatic compilation remains off. To pause refresh, set "
            .. "vim.g.java_build_configuration_update = 'disabled' in init.lua and restart Neovim.")
            :format(vim.fs.basename(root), report.inspected), vim.log.levels.WARN)
    end
    local elapsed = (uv.hrtime() - started) / 1e6
    if elapsed > 1000 then
        notify(("Local Gradle metadata check took %.1fs; checked once per project, not on every buffer.")
            :format(elapsed / 1000), vim.log.levels.WARN)
    end
end

return M
