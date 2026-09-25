# container-env-probe

Read-only inventory of a container's own runtime boundary. Prints namespaces, mounts,
capabilities, cgroup, interfaces, routes and listening sockets to stdout, then serves a
static `200 ok` on port 80 so the container stays healthy.

Environment variables are reported as **names and value lengths only**, never values.
