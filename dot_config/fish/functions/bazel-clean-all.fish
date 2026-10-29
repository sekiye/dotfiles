function bazel-clean-all --description 'このリポジトリ内でビルドされた全ワークスペースを bazel clean する'
    # リポジトリのルート（submodule の中で実行するとその submodule のルートになる）
    set -l root (git rev-parse --show-toplevel); or return 1
    set -l failed 0

    # 既定の output_user_root。startup --output_user_root を変えた場合はここも変える
    for f in ~/.cache/bazel/_bazel_$USER/*/DO_NOT_BUILD_HERE
        set -l ws (cat $f)
        test -d "$ws"; or continue   # ワークスペースが消えている output base は飛ばす

        # ルート自身か、ルートの下にあるワークスペースだけを対象にする
        # （"$root*" と書くと /repo-old のような別のディレクトリにも一致するので "/" を付ける）
        if test "$ws" = "$root"; or string match -q -- "$root/*" "$ws"
            echo ">> bazel clean $argv: $ws" >&2
            env -C "$ws" bazel clean $argv; or set failed 1
        end
    end
    return $failed
end
