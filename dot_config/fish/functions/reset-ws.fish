function reset-ws --description 'ワークスペースを初期化して .bazelrc.user を作り直す'
    bazel-clean-all --expunge && \
    git submodule deinit --all -f && git checkout -- . && git clean -fxd && \
    git lfs pull && \
    git submodule update --init --recursive --force && \
    git submodule foreach --recursive 'git reset --hard && git clean -fdx && git lfs pull' && \
    printf '%s\n' \
        "build --disk_cache=$HOME/bazel_disk_cache" \
        'build --experimental_disk_cache_gc_max_size=50G' \
        'build --experimental_disk_cache_gc_max_age=14d' \
        'build --incompatible_strict_action_env' \
        'build --jobs=64' \
        'build --local_resources=cpu=HOST_CPUS' \
        'build --local_resources=memory=HOST_RAM*.8' \
        "build --repo_env=PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        > .bazelrc.user
end