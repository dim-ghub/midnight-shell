local function get_version()
    local handle = io.popen("git ls-remote --tags --refs https://github.com/caelestia-dots/shell 2>/dev/null | awk -F/ '{print $3}' | grep '^v' | sort -V | tail -n 1")
    if not handle then return "unknown" end
    local result = handle:read("*a")
    handle:close()
    local ver = result:gsub("\n", ""):gsub("^v", "")
    if ver == "" then return "unknown" end
    return ver
end

bldit_version = "0.1.3"
package_name = "caelestia-shell"
package_version = get_version()
global_dependencies = {
    caelestia_cli = {
        url = "https://github.com/dim-ghub/caelestia-cli.git",
        target = "default"
    }
}
dependencies = {}

local legacy_libs = {
    "/usr/lib/qt6/qml/Caelestia/Components/libcaelestia-components.so",
    "/usr/lib/qt6/qml/Caelestia/Config/libcaelestia-config.so",
    "/usr/lib/qt6/qml/Caelestia/Internal/libcaelestia-internal.so",
    "/usr/lib/qt6/qml/Caelestia/Models/libcaelestia-models.so",
    "/usr/lib/qt6/qml/Caelestia/Services/libcaelestia-services.so",
    "/usr/lib/qt6/qml/Caelestia/Blobs/libcaelestia-blobs.so",
    "/usr/lib/qt6/qml/Caelestia/Images/libcaelestia-images.so",
    "/usr/lib/qt6/qml/Caelestia/libcaelestia.so"
}

local paths_to_remove = {
    "/usr/lib/qt6/qml/Caelestia",
    "/usr/lib/qt6/qml/M3Shapes",
    "/usr/lib/caelestia",
    "/etc/xdg/quickshell/caelestia"
}

local function cachyos_user_agreement()
    local script = [=[
exec < /dev/tty
echo "Are you currently using CachyOS? (y/N)"
read response
response=$(echo "$response" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
if [ "$response" = "y" ] || [ "$response" = "yes" ]; then
    cat << 'EOF'
===============================================================================
CACHYOS USER AGREEMENT AND WAIVER OF SUPPORT

By proceeding with this installation on CachyOS, you hereby acknowledge,
consent, and agree to the following terms and conditions:

1. You fully waive any and all rights, claims, or expectations to receive 
   technical support, assistance, guidance, or troubleshooting of any kind 
   from the developers, maintainers, or contributors of this software.
2. You accept that any issues, bugs, system instabilities, or damages 
   encountered during or after the installation process are solely your 
   own responsibility.
3. Any requests for support submitted by you will be categorically ignored, 
   dismissed, or summarily closed without further action or consideration.

Do you acknowledge and agree to these terms? (y/N)
===============================================================================
EOF
    read agree
    agree=$(echo "$agree" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ "$agree" != "y" ] && [ "$agree" != "yes" ]; then
        echo "Installation aborted: You must agree to the terms to proceed on CachyOS."
        exit 1
    fi
else
    if grep -qi "cachyos" /etc/os-release 2>/dev/null; then
        echo "Liar detected! We do not tolerate liars. Installation aborted."
        exit 1
    fi
fi
]=]
    local script_file = os.tmpname()
    local f = io.open(script_file, "w")
    f:write(script)
    f:close()
    os.execute("chmod +x " .. script_file)
    local ret = os.execute("sh " .. script_file)
    os.remove(script_file)
    if ret ~= 0 and ret ~= true then
        os.exit(1)
    end
end

local function install_arch_deps(quiet)
    local q_flag = quiet and " >/dev/null 2>&1" or ""
    if os.execute("command -v pacman >/dev/null 2>&1") == 0 then
        os.execute("sudo pacman -Rdd --noconfirm caelestia-shell caelestia-shell-git >/dev/null 2>&1")
        local deps = "ddcutil brightnessctl networkmanager lm_sensors fish aubio pipewire qt6-declarative qt6-base tensaku libqalculate cmake ninja"
        local aur_deps = "quickshell-git app2unit libcava"
        
        if os.execute("command -v yay >/dev/null 2>&1") == 0 then
            os.execute("yay -S --needed --noconfirm " .. deps .. " " .. aur_deps .. q_flag)
        elseif os.execute("command -v paru >/dev/null 2>&1") == 0 then
            os.execute("paru -S --needed --noconfirm " .. deps .. " " .. aur_deps .. q_flag)
        else
            os.execute("sudo pacman -S --needed --noconfirm " .. deps .. q_flag)
            if not quiet then
                print("Please install the following AUR packages manually: " .. aur_deps)
            end
        end
    end
    return 0
end

targets = {
    default = {
        pre_build = function() return install_arch_deps(false) end,
        build = function() 
            cachyos_user_agreement()
            os.execute("rm -rf build")
            os.execute("cmake -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DVERSION=" .. package_version)
            os.execute("cmake --build build -j$(nproc)")
            return 0
        end,
        install = function() 
            for _, lib in ipairs(legacy_libs) do
                os.execute("sudo rm -f " .. lib)
            end
            os.execute("sudo cmake --install build")
            return 0
        end,
        uninstall = function()
            for _, p in ipairs(paths_to_remove) do
                os.execute("sudo rm -rf " .. p)
            end
            for _, lib in ipairs(legacy_libs) do
                os.execute("sudo rm -f " .. lib)
            end
            os.execute("rm -rf build")
            return 0
        end,
    },
    quiet = {
        pre_build = function() return install_arch_deps(true) end,
        build = function() 
            cachyos_user_agreement()
            os.execute("rm -rf build >/dev/null 2>&1")
            os.execute("cmake -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DVERSION=" .. package_version .. " >/dev/null 2>&1")
            os.execute("cmake --build build -j$(nproc) >/dev/null 2>&1")
            return 0
        end,
        install = function() 
            for _, lib in ipairs(legacy_libs) do
                os.execute("sudo rm -f " .. lib .. " >/dev/null 2>&1")
            end
            os.execute("sudo cmake --install build >/dev/null 2>&1")
            return 0
        end,
        uninstall = function()
            for _, p in ipairs(paths_to_remove) do
                os.execute("sudo rm -rf " .. p .. " >/dev/null 2>&1")
            end
            for _, lib in ipairs(legacy_libs) do
                os.execute("sudo rm -f " .. lib .. " >/dev/null 2>&1")
            end
            os.execute("rm -rf build >/dev/null 2>&1")
            return 0
        end,
    }
}
