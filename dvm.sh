#!/usr/bin/env bash
# source this script

export DVM_VERSION="v0.5.1"

dvm_success() {
  # execute true to set as success
  true
}

dvm_failure() {
  # execute false to set as fail
  false
}

dvm_compare_version() {
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$2"
}

dvm_has() {
  command -v "$1" > /dev/null
}

dvm_get_color() {
  local color="$1"

  case "$color" in
    red)
      DVM_PRINT_COLOR='\x1b[31m'
      ;;
    green)
      DVM_PRINT_COLOR='\x1b[32m'
      ;;
    yellow)
      DVM_PRINT_COLOR='\x1b[33m'
      ;;
    blue)
      DVM_PRINT_COLOR='\x1b[34m'
      ;;
    *)
      ;;
  esac
}

dvm_print() {
  if [ "$DVM_QUIET_MODE" = true ]
  then
    return
  fi

  DVM_PRINT_COLOR=""

  dvm_get_color "$1"
  if [ "$DVM_PRINT_COLOR" != "" ]
  then
    shift
  fi

  if [ "$DVM_COLOR_MODE" = true ]
  then
    echo -e "$DVM_PRINT_COLOR$*\x1b[37m"
  else
    echo -e "$@"
  fi
}

dvm_get_package_data() {
  local target_version

  DVM_TARGET_OS=$(uname -s)
  DVM_TARGET_ARCH=$(uname -m)
  target_version="$1"

  if [ "$DVM_TARGET_OS" = "Darwin" ] &&
    [ "$DVM_TARGET_ARCH" = 'arm64' ] &&
    dvm_compare_version "$target_version" "v1.6.0"
  then
    dvm_print "red" '[ERR] aarch64-darwin support deno v1.6.0 and above versions only.'
    dvm_failure
    return
  fi

  if dvm_compare_version "$target_version" "v0.36.0"
  then
    DVM_TARGET_TYPE="gz"
    DVM_FILE_TYPE="gzip compressed data"
  else
    DVM_TARGET_TYPE="zip"
    DVM_FILE_TYPE="Zip archive data"
  fi

  case "$DVM_TARGET_OS:$DVM_TARGET_ARCH:$DVM_TARGET_TYPE" in
    "Darwin:x86_64:gz")
      DVM_TARGET_NAME='deno_osx_x64.gz'
      ;;
    "Linux:x86_64:gz")
      DVM_TARGET_NAME='deno_linux_x64.gz'
      ;;
    "Darwin:x86_64:zip")
      DVM_TARGET_NAME='deno-x86_64-apple-darwin.zip'
      ;;
    "Darwin:arm64:zip")
      DVM_TARGET_NAME='deno-aarch64-apple-darwin.zip'
      ;;
    "Linux:x86_64:zip")
      DVM_TARGET_NAME='deno-x86_64-unknown-linux-gnu.zip'
      ;;
    *)
      dvm_print "red" "[ERR] unsupported operating system $DVM_TARGET_OS ($DVM_TARGET_ARCH)."
      dvm_failure
      ;;
  esac
}

# dvm_get_latest_version
# Calls GitHub api to getting deno latest release tag name.
dvm_get_latest_version() {
  # the url of github api
  local latest_url
  # the response of requesting deno latest version
  local response
  # the latest release tag name
  local tag_name

  dvm_print "\ntry to getting deno latest version ..."

  latest_url="https://api.github.com/repos/denoland/deno/releases/latest"

  if ! dvm_has curl
  then
    dvm_print "red" "[ERR] curl is required."
    dvm_failure
    return
  fi

  cmd="curl -s $latest_url"
  if [ "$DVM_QUIET_MODE" = true ]
  then
    cmd="$cmd -s"
  fi

  if ! response=$(eval "$cmd")
  then
    dvm_print "red" "[ERR] failed to getting deno latest version."
    dvm_failure
    return
  fi

  tag_name=$(echo "$response" | grep tag_name | cut -d '"' -f 4)

  if [ -z "$tag_name" ]
  then
    dvm_print "red" "[ERR] failed to getting deno latest version."
    dvm_failure
    return
  fi

  DVM_TARGET_VERSION="$tag_name"
}

dvm_download_file() {
  local cmd
  local version
  local url
  local temp_file

  version="$1"

  if [ ! -d "$DVM_DIR/download/$version" ]
  then
    mkdir -p "$DVM_DIR/download/$version"
  fi

  if [ -z "$DVM_INSTALL_REGISTRY" ]
  then
    DVM_INSTALL_REGISTRY="https://github.com/denoland/deno/releases/download"
  fi

  url="$DVM_INSTALL_REGISTRY/$version/$DVM_TARGET_NAME"
  temp_file="$DVM_DIR/download/$version/deno-downloading.$DVM_TARGET_TYPE"

  if dvm_has wget
  then
    cmd="wget $url -O $temp_file"
    if [ "$DVM_QUIET_MODE" = true ]
    then
      cmd="$cmd -q"
    fi
  elif dvm_has curl
  then
    cmd="curl -LJ $url -o $temp_file"
    if [ "$DVM_QUIET_MODE" = true ]
    then
      cmd="$cmd -s"
    fi
  else
    dvm_print "red" "[ERR] wget or curl is required."
    dvm_failure
    return
  fi

  if eval "$cmd"
  then
    local file_type
    file_type=$(file "$temp_file")

    if [[ $file_type == *"$DVM_FILE_TYPE"* ]]
    then
      mv "$temp_file" "$DVM_DIR/download/$version/deno.$DVM_TARGET_TYPE"
      return
    fi
  fi

  if [ -f "$temp_file" ]
  then
    rm "$temp_file"
  fi

  dvm_print "red" "[ERR] failed to download deno $version."
  dvm_failure
}

dvm_extract_file() {
  local target_dir

  target_dir="$DVM_DIR/versions/$1"

  if [ ! -d "$target_dir" ]
  then
    mkdir -p "$target_dir"
  fi

  case $DVM_TARGET_TYPE in
  "zip")
    if dvm_has unzip
    then
      unzip "$DVM_DIR/download/$1/deno.zip" -d "$target_dir" > /dev/null
    elif [ "$DVM_TARGET_OS" = "Linux" ] && dvm_has gunzip
    then
      gunzip -c "$DVM_DIR/download/$1/deno.zip" > "$target_dir/deno"
      chmod +x "$target_dir/deno"
    else
      dvm_print "red" "[ERR] unzip is required."
      dvm_failure
    fi
    ;;
  "gz")
    if dvm_has gunzip
    then
      gunzip -c "$DVM_DIR/download/$1/deno.gz" > "$target_dir/deno"
      chmod +x "$target_dir/deno"
    else
      dvm_print "red" "[ERR] gunzip is required."
      dvm_failure
    fi
    ;;
  *)
    ;;
  esac
}

# dvm_validate_remote_version
# Get remote version data by GitHub api (Get a release by tag name)
dvm_validate_remote_version() {
  local version
  local target_version
  # GitHub get release by tag name api url
  local tag_url

  version="$1"

  if [[ "$version" != "v"* ]]
  then
    target_version="v$version"
  else
    target_version="$version"
  fi

  tag_url="https://api.github.com/repos/denoland/deno/releases/tags/$target_version"

  if ! dvm_has curl
  then
    dvm_print "red" "[ERR] curl is required."
    dvm_failure
    return
  fi

  cmd="curl -s $tag_url"
  if [ "$DVM_QUIET_MODE" = true ]
  then
    cmd="$cmd -s"
  fi

  if ! response=$(eval "$cmd")
  then
    dvm_print "red" "[ERR] failed to getting deno $version data."
    dvm_failure
    return
  fi

  tag_name=$(echo "$response" | grep tag_name | cut -d '"' -f 4)

  if [ -z "$tag_name" ]
  then
    dvm_print "red" "[ERR] deno '$version' not found, use 'ls-remote' command to get available versions."
    dvm_failure
  fi
}

dvm_install_version() {
  local version

  version="$1"

  if [ -z "$version" ]
  then
    if ! dvm_get_latest_version
    then
      return
    fi
    version="$DVM_TARGET_VERSION"
  fi

  if [ -f "$DVM_DIR/versions/$version/deno" ]
  then
    dvm_print "Deno $version has been installed."
    dvm_success
    return
  fi

  if ! dvm_validate_remote_version "$version"
  then
    return
  fi

  if [[ "$version" != "v"* ]]
  then
    version="v$version"
  fi

  if ! dvm_get_package_data "$version"
  then
    return
  fi

  if [ ! -f "$DVM_DIR/download/$version/deno.$DVM_TARGET_TYPE" ]
  then
    dvm_print "Downloading and installing deno $version..."
    if ! dvm_download_file "$version"
    then
      return
    fi
  else
    dvm_print "Installing deno $version from cache..."
  fi

  if ! dvm_extract_file "$version"
  then
    return
  fi

  dvm_print "Deno $version has installed."
}

dvm_uninstall_version() {
  local input_version

  input_version="$1"

  dvm_get_current_version

  if [ "$DVM_DENO_VERSION" = "$DVM_TARGET_VERSION" ]
  then
    dvm_print "Cannot active deno version ($DVM_DENO_VERSION)."
    dvm_failure
    return
  fi

  if [ -f "$DVM_DIR/versions/$DVM_TARGET_VERSION/deno" ]
  then
    rm -rf "$DVM_DIR/versions/$DVM_TARGET_VERSION"

    dvm_print "Uninstalled deno $DVM_TARGET_VERSION."
  else
    dvm_print "Deno $DVM_TARGET_VERSION is not installed."
  fi

  if [ -n "$input_version" ] && [ "$input_version" != "$DVM_TARGET_VERSION" ] && [ -f "$DVM_DIR/aliases/$input_version" ]
  then
    rm "$DVM_DIR/aliases/$input_version"
  fi
}

dvm_list_aliases() {
  local aliased_version

  if [ ! -d "$DVM_DIR/aliases" ]
  then
    return
  fi

  if [ -z "$(ls -A "$DVM_DIR/aliases")" ]
  then
    return
  fi

  for alias_path in "$DVM_DIR/aliases"/*
  do
    if [ ! -f "$alias_path" ]
    then
      continue;
    fi

    alias_name=${alias_path##*/}
    aliased_version=$(cat "$alias_path")

    if [ -z "$aliased_version" ] ||
      [ ! -f "$DVM_DIR/versions/$aliased_version/deno" ]
    then
      dvm_print "$alias_name -> N/A"
    else
      dvm_print "$alias_name -> $aliased_version"
    fi
  done
}

dvm_list_local_versions() {
  local version

  if [ ! -d "$DVM_DIR/versions" ]
  then
    return
  fi

  if [ -z "$(ls -A "$DVM_DIR/versions")" ]
  then
    return
  fi

  for dir in "$DVM_DIR/versions"/*
  do
    if [ ! -f "$dir/deno" ]
    then
      continue
    fi

    version=${dir##*/}

    if [ "$version" = "$DVM_DENO_VERSION" ]
    then
      dvm_print "green" "-> $version"
    else
      dvm_print "   $version"
    fi
  done
}

dvm_list_remote_versions() {
  local releases_url
  local all_versions
  local page
  local size
  local num
  local tmp_versions
  local response

  page=1
  size=100
  num="$size"
  releases_url="https://api.github.com/repos/denoland/deno/releases\?per_page=$size"

  while [ "$num" -eq "$size" ]
  do
    if ! dvm_has curl
    then
      dvm_print "red" "[ERR] curl is required."
      dvm_failure
      return
    fi

    cmd="curl -s $releases_url\&page=$page"
    if [ "$DVM_QUIET_MODE" = true ]
    then
      cmd="$cmd -s"
    fi

    if ! response=$(eval "$cmd")
    then
      dvm_print "red" "[ERR] failed to list remote versions."
      dvm_failure
      return
    fi

    tmp_versions=$(echo "$response" | grep tag_name | cut -d '"' -f 4)
    num=$(echo "$tmp_versions" | wc -l)
    page=$((page + 1))

    if [ -n "$all_versions" ]
    then
      all_versions="$all_versions\n$tmp_versions"
    else
      all_versions="$tmp_versions"
    fi
  done

  echo -e "$all_versions" | sed 'x;1!H;$!d;x'
}

dvm_check_dvm_dir() {
  if [ -z "$DVM_DIR" ]
  then
    # set default dvm directory
    DVM_DIR="$HOME/.dvm"
  fi
}

dvm_set_default_env() {
  DVM_COLOR_MODE=false
  DVM_QUIET_MODE=false
}

dvm_clean_download_cache() {
  if [ ! -d "$DVM_DIR/download" ]
  then
    return
  fi

  if [ -z "$(ls -A "$DVM_DIR/download")" ]
  then
    return
  fi

  for cache_path in "$DVM_DIR/download"/*
  do
    if [ ! -d "$cache_path" ]
    then
      continue
    fi

    [ -f "$cache_path/deno-downloading.zip" ] && rm "$cache_path/deno-downloading.zip"

    [ -f "$cache_path/deno-downloading.gz" ] && rm "$cache_path/deno-downloading.gz"

    [ -f "$cache_path/deno.zip" ] && rm "$cache_path/deno.zip"

    [ -f "$cache_path/deno.gz" ] && rm "$cache_path/deno.gz"

    rmdir "$cache_path"
  done
}

dvm_get_version_by_param() {
  DVM_TARGET_VERSION=""

  
  while [[ "$1" == "-"* ]]
  do
    shift
  done

  if [ "$#" = "0" ]
  then
    return
  fi

  if [ -f "$DVM_DIR/aliases/$1" ]
  then
    DVM_TARGET_VERSION=$(cat "$DVM_DIR/aliases/$1")

    if [ ! -f "$DVM_DIR/versions/$DVM_TARGET_VERSION/deno" ]
    then
      DVM_TARGET_VERSION="$1"
    fi
  else
    DVM_TARGET_VERSION="$1"
  fi
}

dvm_get_version() {
  local version

  dvm_get_version_by_param "$@"

  if [ -n "$DVM_TARGET_VERSION" ]
  then
    return
  fi

  if [ ! -f "./.dvmrc" ]
  then
    dvm_print "No .dvmrc file found."
    return
  fi

  DVM_TARGET_VERSION=$(cat ./.dvmrc)
}

dvm_strip_path() {
  echo "$PATH" | tr ":" "\n" | grep -v "$DVM_DIR" | tr "\n" ":"
}

# dvm_use_version
# Create a symbolic link file to make the specified deno version as active
# version, the symbolic link is linking to the specified deno executable file.
dvm_use_version() {
  # deno executable file version
  local deno_version
  # target deno executable file path
  local target_path
  local path_without_dvm

  dvm_get_version "$1"

  if [ -z "$DVM_TARGET_VERSION" ]
  then
    dvm_print_help
    dvm_failure
    return
  fi

  target_dir="$DVM_DIR/versions/$DVM_TARGET_VERSION"
  target_path="$target_dir/deno"

  if [ -f "$target_path" ]
  then
    # get target deno executable file version
    deno_version=$("$target_path" --version 2>/dev/null | grep deno | cut -d " " -f 2)

    if [ -n "$deno_version" ] && [ "$DVM_TARGET_VERSION" != "v$deno_version" ]
    then
      # print warnning message when deno version is different with parameter.
      dvm_print "yellow" "[WARN] You may had upgraded this version, it is v$deno_version now."
    fi

    # export PATH with the target dir in front
    path_without_dvm=$(dvm_strip_path)
    export PATH="$target_dir":${path_without_dvm}

    dvm_print "Using deno $DVM_TARGET_VERSION now."
  else
    dvm_print "Deno $DVM_TARGET_VERSION is not installed, you can run 'dvm install $DVM_TARGET_VERSION' to install it."
    dvm_failure
  fi
}

dvm_get_current_version() {
  local deno_path
  local deno_dir

  if ! deno_path=$(which deno 2>/dev/null)
  then
    return
  fi

  if [[ "$deno_path" != "$DVM_DIR/versions/"* ]]
  then
    return
  fi

  deno_dir=${deno_path%/deno}

  DVM_DENO_VERSION=${deno_dir##*/}
}

dvm_deactivate() {
  local path_without_dvm

  dvm_get_current_version

  if [ -z "$DVM_DENO_VERSION" ]
  then
    dvm_success
    return
  fi

  path_without_dvm=$(dvm_strip_path)
  export PATH="$path_without_dvm"

  dvm_print "Deno has been deactivated, you can run \"dvm use $DVM_DENO_VERSION\" to restore it."

  unset DVM_DENO_VERSION
}

dvm_check_alias_dir() {
  if [ ! -d "$DVM_DIR/aliases" ]
  then
    mkdir -p "$DVM_DIR/aliases"
  fi
}

dvm_set_alias() {
  local alias_name
  local version

  dvm_check_alias_dir

  alias_name="$1"
  version="$2"

  if [ ! -f "$DVM_DIR/versions/$version/deno" ]
  then
    dvm_print "red" "[ERR] deno $version is not installed."
    dvm_failure
    return
  fi

  dvm_print "$version" > "$DVM_DIR/aliases/$alias_name"

  dvm_print "$alias_name -> $version"
}

dvm_rm_alias() {
  local alias_name
  local aliased_version

  dvm_check_alias_dir

  alias_name="$1"

  if [ ! -f "$DVM_DIR/aliases/$alias_name" ]
  then
    dvm_print "red" "[ERR] alias $alias_name does not exist."
    dvm_failure
    return
  fi

  aliased_version=$(cat "$DVM_DIR/aliases/$alias_name")

  rm "$DVM_DIR/aliases/$alias_name"

  dvm_print "Deleted alias $alias_name."
  dvm_print "Restore it with 'dvm alias $alias_name $aliased_version'."
}

dvm_run_with_version() {
  if [ ! -f "$DVM_DIR/versions/$DVM_TARGET_VERSION/deno" ]
  then
    dvm_print "red" "[ERR] deno $DVM_TARGET_VERSION is not installed."
    dvm_failure
    return
  fi

  dvm_print "Running with deno $DVM_TARGET_VERSION."

  "$DVM_DIR/versions/$DVM_TARGET_VERSION/deno" "$@"
}

dvm_locate_version() {
  local target_version

  target_version="$DVM_TARGET_VERSION"

  if [ "$1" = "current" ]
  then
    dvm_get_current_version
    if [ -n "$DVM_DENO_VERSION" ]
    then
      target_version="$DVM_DENO_VERSION"
    fi
  fi

  if [ -f "$DVM_DIR/versions/$target_version/deno" ]
  then
    dvm_print "$DVM_DIR/versions/$target_version/deno"
  else
    dvm_print "Deno $target_version is not installed."
  fi
}

dvm_get_dvm_latest_version() {
  local request_url
  local field
  local response

  case "$DVM_SOURCE" in
  gitee)
    request_url="https://gitee.com/api/v5/repos/ghosind/dvm/releases/latest"
    field="6"
    ;;
  github|*)
    request_url="https://api.github.com/repos/ghosind/dvm/releases/latest"
    field="4"
    ;;
  esac

  if ! dvm_has curl
  then
    dvm_print "red" "[ERR] curl is required."
    dvm_failure
    return
  fi

  cmd="curl -s $request_url"
  if [ "$DVM_QUIET_MODE" = true ]
  then
    cmd="$cmd -s"
  fi

  if ! response=$(eval "$cmd")
  then
    dvm_print "red" "[ERR] failed to get the latest DVM version."
    dvm_failure
    return
  fi

  DVM_LATEST_VERSION=$(echo "$response" | grep tag_name | cut -d '"' -f $field)
}

dvm_update_dvm() {
  if ! cd "$DVM_DIR" 2>/dev/null
  then
    dvm_print "red" "[ERR] failed to update dvm."
    dvm_failure
    return
  fi

  # reset changes if exists
  git reset --hard HEAD
  git fetch
  git checkout "$DVM_LATEST_VERSION"

  dvm_print "DVM has upgrade to latest version."
}

dvm_fix_invalid_versions() {
  local version

  if [ ! -d "$DVM_DIR/doctor_temp" ]
  then
    return
  fi

  for version_path in "$DVM_DIR/doctor_temp/"*
  do
    version=${version_path##*/}

    if [ -d "$DVM_DIR/versions/$version" ]
    then
      rm -rf "$version_path"
    else
      mv "$version_path" "$DVM_DIR/versions/$version"
    fi
  done

  rmdir "$DVM_DIR/doctor_temp"

  dvm_print "Invalid version(s) has been fixed."
}

dvm_print_doctor_message() {
  local invalid_message
  local corrupted_message

  invalid_message="$1"
  corrupted_message="$2"

  if [ -z "$invalid_message" ] && [ -z "$corrupted_message" ]
  then
    dvm_print "Everything is ok."
    return
  fi

  if [ -n "$invalid_message" ]
  then
    dvm_print "Invalid versions:"
    dvm_print "$invalid_message"
  fi

  if [ -n "$corrupted_message" ]
  then
    dvm_print "Corrupted versions:"
    dvm_print "$corrupted_message"
  fi

  dvm_print "You can run \"dvm doctor --fix\" to fix these errors."
}

dvm_scan_and_fix_versions() {
  local mode
  local raw_output
  local invalid_message
  local corrupted_message
  local version
  local deno_version

  mode="$1"

  if [ ! -d "$DVM_DIR/versions" ]
  then
    return
  fi

  if [ -z "$(ls -A "$DVM_DIR/versions")" ]
  then
    return
  fi

  for version_path in "$DVM_DIR/versions/"*
  do
    if [ ! -f "$version_path/deno" ]
    then
      continue
    fi

    version=${version_path##*/}

    raw_output=$("$version_path/deno" --version 2>/dev/null)

    if [ -z "$raw_output" ]
    then
      corrupted_message="$corrupted_message$version\n"

      if [ "$mode" = "fix" ]
      then
        rm -rf "$version_path"
      fi
    else
      deno_version=$(echo "$raw_output" | grep deno | cut -d " " -f 2)

      if [ "$version" != "v$deno_version" ]
      then
        invalid_message="$invalid_message$version -> v$deno_version\n"

        if [ "$mode" = "fix" ]
        then
          mkdir -p "$DVM_DIR/doctor_temp"
          mv -f "$version_path" "$DVM_DIR/doctor_temp/v$deno_version"
        fi
      fi
    fi
  done

  if [ "$mode" = "fix" ]
  then
    dvm_fix_invalid_versions
  else
    dvm_print_doctor_message "$invalid_message" "$corrupted_message"
  fi
}

dvm_get_rc_file() {
  case ${SHELL##*/} in
  bash)
    DVM_RC_FILE="$HOME/.bashrc"
    ;;
  zsh)
    DVM_RC_FILE="$HOME/.zshrc"
    ;;
  *)
    DVM_RC_FILE="$HOME/.profile"
    ;;
  esac
}

dvm_confirm_with_prompt() {
  local confirm
  local prompt

  if [ "$#" = 0 ]
  then
    return
  fi

  prompt="$1"
  echo -n "$prompt (y/n): "

  while true
  do
    read -r confirm

    case "$confirm" in
    y|Y)
      return 0
      ;;
    n|N)
      return 1
      ;;
    *)
      ;;
    esac

    echo -n "Please type 'y' or 'n': "
  done
}

dvm_purge_dvm() {
  local content

  rm -rf "$DVM_DIR"

  dvm_get_rc_file

  content=$(sed "/Deno Version Manager/d;/DVM_DIR/d;/DVM_BIN/d" "$DVM_RC_FILE")
  echo "$content" > "$DVM_RC_FILE"

  unset -v DVM_BIN DVM_COLOR_MODE DVM_DENO_VERSION DVM_DIR DVM_FILE_TYPE7 \
    DVM_INSTALL_REGISTRY DVM_LATEST_VERSION DVM_RC_FILE DVM_PRINT_COLOR \
    DVM_QUIET_MODE DVM_SOURCE DVM_TARGET_ARCH DVM_TARGET_NAME DVM_TARGET_OS \
    DVM_TARGET_TYPE DVM_TARGET_VERSION DVM_VERSION
  unset -f dvm
  unset -f dvm_check_alias_dir dvm_check_dvm_dir dvm_clean_download_cache \
    dvm_compare_version dvm_confirm_with_prompt dvm_deactivate \
    dvm_download_file dvm_extract_file dvm_failure dvm_fix_invalid_versions \
    dvm_get_color dvm_get_current_version dvm_get_dvm_latest_version \
    dvm_get_latest_version dvm_get_package_data dvm_get_rc_file dvm_get_version \
    dvm_get_version_by_param dvm_has dvm_install_version dvm_list_aliases \
    dvm_list_local_versions dvm_list_remote_versions dvm_locate_version \
    dvm_parse_options dvm_print dvm_print_doctor_message dvm_print_help \
    dvm_purge_dvm dvm_rm_alias dvm_run_with_version dvm_scan_and_fix_versions \
    dvm_set_alias dvm_set_default_env dvm_strip_path dvm_success \
    dvm_uninstall_version dvm_update_dvm dvm_use_version \
    dvm_validate_remote_version

  echo "DVM has been removed from your computer."
}

dvm_parse_options() {
  while [ "$#" -gt "0" ]
  do
    case "$1" in
      -q|--quiet)
        DVM_QUIET_MODE=true
        ;;
      --color)
        DVM_COLOR_MODE=true
        ;;
      --no-color)
        DVM_COLOR_MODE=false
        ;;
    esac

    shift
  done
}

dvm_print_help() {
  printf "
Deno Version Manager

Usage:
  dvm install                       Download and install the latest version or the version reading from .dvmrc file.
    [version]                       Download and install the specified version from source.
    [--registry=<registry>]         Download and install deno with the specified registry.
  dvm uninstall [name|version]      Uninstall a specified version.
  dvm use [name|version]            Use the specified version that passed by argument or read from .dvmrc.
  dvm run <name|version> [args]     Run deno on the specified version with arguments.
  dvm alias <name> <version>        Set an alias name to specified version.
  dvm unalias <name|version>        Delete the specified alias name.
  dvm current                       Display the current version of Deno.
  dvm ls                            List all installed versions.
  dvm ls-remote                     List all remote versions.
  dvm which [current|name|version]  Display the path of installed version.
  dvm clean                         Remove all downloaded packages.
  dvm deactivate                    Deactivate Deno on current shell.
  dvm doctor                        Scan installed versions and find invalid / corrupted versions.
    [--fix]                         Scan and fix all invalid / corrupted versions.
  dvm upgrade                       Upgrade dvm itself.
  dvm purge                         Remove dvm from your computer.
  dvm help                          Show this message.

Options:
  -q, --quiet                       Make outputs more quiet.
  --color                           Print colorful messages.
  --no-color                        Print messages without color.

Note:
  <param> is required paramter, [param] is optional paramter.

Examples:
  dvm install v1.0.0
  dvm uninstall v0.42.0
  dvm use v1.0.0
  dvm alias default v1.0.0
  dvm run v1.0.0 app.ts

"
}

dvm() {
  local version
  dvm_check_dvm_dir
  dvm_set_default_env

  if [ "$#" = "0" ]
  then
    dvm_print_help
    dvm_success
    return
  fi

  dvm_parse_options "$@"

  case $1 in
  install)
    # install the specified version
    shift

    version=""

    while [ "$#" -gt "0" ]
    do
      case "$1" in
      "--registry="*)
        DVM_INSTALL_REGISTRY=${1#--registry=}
        ;;
      "-"*)
        ;;
      *)
        version="$1"
        ;;
      esac

      shift
    done

    if [ -z "$version" ]
    then
      if [ -f "./.dvmrc" ]
      then
        version=$(cat ./.dvmrc)
      else
        dvm_print "No .dvmrc file found"
      fi
    fi

    dvm_install_version "$version"

    ;;
  uninstall)
    # uninstall the specified version
    shift

    dvm_get_version "$@"
    if [ "$DVM_TARGET_VERSION" = "" ]
    then
      dvm_print_help
      dvm_failure
      return
    fi

    dvm_uninstall_version "$DVM_TARGET_VERSION"

    ;;
  list | ls)
    # list all local versions
    dvm_get_current_version

    dvm_list_local_versions

    dvm_list_aliases

    ;;
  list-remote | ls-remote)
    # list all remote versions
    dvm_list_remote_versions

    ;;
  current)
    # get the current version

    if ! dvm_has deno
    then
      dvm_print "none"
      return
    fi

    dvm_get_current_version

    if [ -n "$DVM_DENO_VERSION" ]
    then
      dvm_print "$DVM_DENO_VERSION"
    else
      version=$(deno --version | grep "deno" | cut -d " " -f 2)
      dvm_print "system (v$version)"
    fi

    ;;
  use)
    # change current version to specified version
    shift

    dvm_use_version "$@"

    ;;
  clean)
    # remove all download packages.
    dvm_clean_download_cache

    ;;
  alias)
    shift

    if [ "$#" -lt "2" ]
    then
      dvm_print_help
      dvm_failure
      return
    fi

    dvm_set_alias "$@"

    ;;
  unalias)
    shift

    if [ "$#" -lt "1" ]
    then
      dvm_print_help
      dvm_failure
      return
    fi

    dvm_rm_alias "$1"

    ;;
  run)
    shift

    dvm_get_version "$@"

    if [ "$DVM_TARGET_VERSION" = "" ]
    then
      dvm_print_help
      dvm_failure
      return
    fi

    if [ "$#" != "0" ]
    then
      shift
    fi

    dvm_run_with_version "$@"

    ;;
  which)
    shift

    dvm_get_version "$@"

    if [ -z "$DVM_TARGET_VERSION" ]
    then
      dvm_print_help
      dvm_failure
      return
    fi

    dvm_locate_version "$@"

    ;;
  upgrade)
    if ! dvm_get_dvm_latest_version
    then
      return
    fi

    if [ "$DVM_LATEST_VERSION" = "$DVM_VERSION" ]
    then
      dvm_print "dvm is update to date."
      dvm_success
      return
    fi

    dvm_update_dvm

    ;;
  doctor)
    local mode

    shift

    mode="scan"

    while [ "$#" -gt "0" ]
    do
      case "$1" in
      "--fix")
        mode="fix"
        ;;
      *)
        dvm_print "red" "[ERR] unsupprot option \"$1\"."
        dvm_failure
        return
        ;;
      esac

      shift
    done

    if [ "$mode" = "fix" ] &&
      ! dvm_confirm_with_prompt "Doctor fix command will remove all duplicated / corrupted versions, do you want to continue?"
    then
      return
    fi

    dvm_scan_and_fix_versions "$mode"

    ;;
  deactivate)
    dvm_deactivate

    ;;
  purge)
    if ! dvm_confirm_with_prompt "Do you want to remove DVM from your computer?"
    then
      return
    fi

    if ! dvm_confirm_with_prompt "Remove dvm will also remove installed deno(s), do you want to continue?"
    then
      return
    fi

    dvm_purge_dvm

    ;;
  help|--help|-h)
    # print help
    dvm_print_help

    ;;
  --version)
    # print dvm version

    dvm_print "$DVM_VERSION"

    ;;
  *)
    dvm_print "red" "[ERR] unknown command $1."
    dvm_print_help
    dvm_failure
    ;;
  esac
}

if [ -f "$DVM_DIR/aliases/default" ]
then
  DVM_QUIET_MODE=true
  dvm use "default"
  DVM_QUIET_MODE=false
fi
