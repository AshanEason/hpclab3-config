help([[
Lab 3 software stack.
]])

whatis("Lab 3 software stack")

local root = "/home/judge/opt/lab3"

prepend_path("PATH", pathJoin(root, "stress-ng-0.19.04", "bin"))
prepend_path("PATH", pathJoin(root, "apptainer-1.4.4", "bin"))
prepend_path("PATH", pathJoin(root, "nccl-tests-2.17.6", "bin"))

prepend_path("LD_LIBRARY_PATH", pathJoin(root, "apptainer-1.4.4", "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "cuda-libs", "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "nccl-2.17.1", "lib"))
prepend_path("LD_LIBRARY_PATH", "/usr/local/cuda/lib64")
prepend_path("LD_LIBRARY_PATH", "/usr/lib/x86_64-linux-gnu")
