"""An HTTP archive rule that symlinks strip_prefix instead of discarding it."""

load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "patch",
    "workspace_and_buildfile",
)

_ARCHIVE_ROOT = ".tmp_archive_root"

def _http_archive_symlink_strip_prefix_impl(repository_ctx):
    if repository_ctx.attr.build_file and repository_ctx.attr.build_file_content:
        fail("Only one of build_file and build_file_content can be provided.")

    strip_prefix_parts = repository_ctx.attr.strip_prefix.split("/")
    if ".." in strip_prefix_parts or repository_ctx.attr.strip_prefix.startswith("/"):
        fail("strip_prefix must be relative and cannot contain '..'")

    repository_ctx.download_and_extract(
        repository_ctx.attr.urls,
        _ARCHIVE_ROOT,
        repository_ctx.attr.sha256,
        repository_ctx.attr.type,
    )

    archive_root = repository_ctx.path(_ARCHIVE_ROOT)
    source_root = archive_root
    if repository_ctx.attr.strip_prefix:
        source_root = archive_root.get_child(repository_ctx.attr.strip_prefix)
    if not source_root.exists:
        fail("strip_prefix '{}' does not exist in the archive".format(repository_ctx.attr.strip_prefix))

    for item in source_root.readdir():
        repository_ctx.symlink(item, repository_ctx.path(item.basename))

    workspace_and_buildfile(repository_ctx)
    patch(repository_ctx)

http_archive_symlink_strip_prefix = repository_rule(
    implementation = _http_archive_symlink_strip_prefix_impl,
    attrs = {
        "build_file": attr.label(allow_single_file = True),
        "build_file_content": attr.string(),
        "patch_args": attr.string_list(default = ["-p0"]),
        "patch_tool": attr.string(),
        "patches": attr.label_list(),
        "remote_patch_strip": attr.int(default = 0),
        "sha256": attr.string(),
        "strip_prefix": attr.string(),
        "type": attr.string(),
        "urls": attr.string_list(mandatory = True),
    },
    doc = """Downloads an archive and symlinks the contents of `strip_prefix` at the repository root.

Unlike `http_archive`, the files outside `strip_prefix` remain available so
relative symlinks from within the selected directory continue to resolve.
""",
)
