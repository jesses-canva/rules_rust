"""An HTTP archive repository rule that exposes a nested package at its root."""

load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "patch",
    "workspace_and_buildfile",
)

_ARCHIVE_ROOT = ".tmp_archive_root"

def _http_archive_with_subdirectory_impl(repository_ctx):
    if repository_ctx.attr.build_file and repository_ctx.attr.build_file_content:
        fail("Only one of build_file and build_file_content can be provided.")

    subdirectory_parts = repository_ctx.attr.crate_subdirectory.split("/")
    if ".." in subdirectory_parts or repository_ctx.attr.crate_subdirectory.startswith("/"):
        fail("crate_subdirectory must be relative and cannot contain '..'")

    repository_ctx.download_and_extract(
        repository_ctx.attr.urls,
        _ARCHIVE_ROOT,
        repository_ctx.attr.sha256,
        repository_ctx.attr.type,
        repository_ctx.attr.strip_prefix,
    )

    archive_root = repository_ctx.path(_ARCHIVE_ROOT)
    crate_root = archive_root.get_child(repository_ctx.attr.crate_subdirectory)
    if not crate_root.exists:
        fail("crate_subdirectory '{}' does not exist in the archive".format(repository_ctx.attr.crate_subdirectory))

    for item in crate_root.readdir():
        repository_ctx.symlink(item, repository_ctx.path(item.basename))

    workspace_and_buildfile(repository_ctx)
    patch(repository_ctx)

http_archive_with_subdirectory = repository_rule(
    implementation = _http_archive_with_subdirectory_impl,
    attrs = {
        "build_file": attr.label(allow_single_file = True),
        "build_file_content": attr.string(),
        "crate_subdirectory": attr.string(mandatory = True),
        "patch_args": attr.string_list(default = ["-p0"]),
        "patch_tool": attr.string(),
        "patches": attr.label_list(),
        "remote_patch_strip": attr.int(default = 0),
        "sha256": attr.string(),
        "strip_prefix": attr.string(),
        "type": attr.string(),
        "urls": attr.string_list(mandatory = True),
    },
    doc = """Downloads an archive while retaining files outside a nested crate.

The full archive is extracted beneath a hidden directory. The direct children
of `crate_subdirectory` are then exposed at the repository root, matching
`git_repository(strip_prefix = ...)` without discarding sibling files that
relative symlinks may reference.
""",
)
