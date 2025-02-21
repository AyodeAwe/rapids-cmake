#=============================================================================
# Copyright (c) 2021, NVIDIA CORPORATION.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#=============================================================================
include_guard(GLOBAL)

#[=======================================================================[.rst:
rapids_cpm_libcudacxx
---------------------

.. versionadded:: v21.12.00

Allow projects to find or build `libcudacxx` via `CPM` with built-in
tracking of these dependencies for correct export support.

Uses the version of libcudacxx :ref:`specified in the version file <cpm_versions>` for consistency
across all RAPIDS projects.

.. code-block:: cmake

  rapids_cpm_libcudacxx( [BUILD_EXPORT_SET <export-name>]
                         [INSTALL_EXPORT_SET <export-name>]
                        )

``BUILD_EXPORT_SET``
  Record that a :cmake:command:`CPMFindPackage(libcudacxx)` call needs to occur as part of
  our build directory export set.

``INSTALL_EXPORT_SET``
  Record a :cmake:command:`find_dependency(libcudacxx)` call needs to occur as part of
  our install directory export set.

Result Targets
^^^^^^^^^^^^^^
  libcudacxx::libcudacxx target will be created

Result Variables
^^^^^^^^^^^^^^^^
  :cmake:variable:`libcudacxx_SOURCE_DIR` is set to the path to the source directory of libcudacxx.
  :cmake:variable:`libcudacxx_BINAR_DIR`  is set to the path to the build directory of  libcudacxx.
  :cmake:variable:`libcudacxx_ADDED`      is set to a true value if libcudacxx has not been added before.
  :cmake:variable:`libcudacxx_VERSION`    is set to the version of libcudacxx specified by the versions.json.

#]=======================================================================]
function(rapids_cpm_libcudacxx)
  list(APPEND CMAKE_MESSAGE_CONTEXT "rapids.cpm.libcudacxx")

  set(install_export FALSE)
  if(INSTALL_EXPORT_SET IN_LIST ARGN)
    set(install_export TRUE)
  endif()

  set(build_export FALSE)
  if(BUILD_EXPORT_SET IN_LIST ARGN)
    set(build_export TRUE)
  endif()

  include("${rapids-cmake-dir}/cpm/detail/package_details.cmake")
  rapids_cpm_package_details(libcudacxx version repository tag shallow)

  include("${rapids-cmake-dir}/cpm/find.cmake")
  rapids_cpm_find(libcudacxx ${version} ${ARGN}
                  GLOBAL_TARGETS libcudacxx::libcudacxx
                  CPM_ARGS
                  GIT_REPOSITORY ${repository}
                  GIT_TAG ${tag}
                  GIT_SHALLOW ${shallow}
                  DOWNLOAD_ONLY TRUE)

  # establish the correct libcudacxx namespace aliases
  if(libcudacxx_ADDED AND NOT TARGET rapids_libcudacxx)
    add_library(rapids_libcudacxx INTERFACE)
    set_target_properties(rapids_libcudacxx PROPERTIES EXPORT_NAME libcudacxx)

    add_library(libcudacxx::libcudacxx ALIAS rapids_libcudacxx)

    target_include_directories(rapids_libcudacxx
                               INTERFACE $<BUILD_INTERFACE:${libcudacxx_SOURCE_DIR}/include>
                                         $<INSTALL_INTERFACE:include/rapids/libcudacxx>)

    install(TARGETS rapids_libcudacxx DESTINATION ${lib_dir} EXPORT libcudacxx-targets)

    set(code_string
        [=[
# nvcc automatically adds the CUDA Toolkit system include paths before any
# system include paths that CMake adds. CMake implicitly treats all includes
# on import targets as 'SYSTEM' includes.
#
# To get this cudacxx to be picked up by consumers instead of the version shipped
# with the CUDA Toolkit we need to make sure it is a non-SYSTEM include on the CMake side.
#
add_library(libcudacxx_includes INTERFACE)
target_link_libraries(libcudacxx::libcudacxx INTERFACE libcudacxx_includes)
get_target_property(all_includes libcudacxx::libcudacxx INTERFACE_INCLUDE_DIRECTORIES)
set_target_properties(libcudacxx::libcudacxx PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "")
set_target_properties(libcudacxx_includes PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${all_includes}")
    ]=])

    if(build_export)
      include("${rapids-cmake-dir}/export/export.cmake")
      rapids_export(BUILD libcudacxx
                    EXPORT_SET libcudacxx-targets
                    GLOBAL_TARGETS libcudacxx
                    VERSION ${version}
                    NAMESPACE libcudacxx::
                    FINAL_CODE_BLOCK code_string)
    endif()

    if(install_export)
      include("${rapids-cmake-dir}/cmake/install_lib_dir.cmake")
      rapids_cmake_install_lib_dir(lib_dir)
      install(DIRECTORY ${libcudacxx_SOURCE_DIR}/include/
              DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/rapids/libcudacxx)
      install(DIRECTORY ${libcudacxx_SOURCE_DIR}/libcxx/include/
              DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/rapids/libcxx/include)

      include("${rapids-cmake-dir}/export/export.cmake")
      rapids_export(INSTALL libcudacxx
                    EXPORT_SET libcudacxx-targets
                    GLOBAL_TARGETS libcudacxx
                    VERSION ${version}
                    NAMESPACE libcudacxx::
                    FINAL_CODE_BLOCK code_string)

    endif()
  endif()

  # Propagate up variables that CPMFindPackage provide
  set(libcudacxx_SOURCE_DIR "${libcudacxx_SOURCE_DIR}" PARENT_SCOPE)
  set(libcudacxx_BINARY_DIR "${libcudacxx_BINARY_DIR}" PARENT_SCOPE)
  set(libcudacxx_ADDED "${libcudacxx_ADDED}" PARENT_SCOPE)
  set(libcudacxx_VERSION ${version} PARENT_SCOPE)

endfunction()
