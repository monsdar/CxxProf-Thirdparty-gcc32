# - SWIG module for CMake
# Defines the following macros:
#   SWIG_ADD_MODULE(name language [ files ])
#     - Define swig module with given name and specified language
#   SWIG_LINK_LIBRARIES(name [ libraries ])
#     - Link libraries to swig module
# All other macros are for internal use only.
# To get the actual name of the swig module,
# use: ${SWIG_MODULE_${name}_REAL_NAME}.
# Set Source files properties such as CPLUSPLUS and SWIG_FLAGS to specify
# special behavior of SWIG. Also global CMAKE_SWIG_FLAGS can be used to add
# special flags to all swig calls.
# Another special variable is CMAKE_SWIG_OUTDIR, it allows one to specify 
# where to write all the swig generated module (swig -outdir option)
# The name-specific variable SWIG_MODULE_<name>_EXTRA_DEPS may be used
# to specify extra dependencies for the generated modules.
# If the source file generated by swig need some special flag you can use
# SET_SOURCE_FILES_PROPERTIES( ${swig_generated_file_fullname}
#        PROPERTIES COMPILE_FLAGS "-bla")


#=============================================================================
# Copyright 2004-2009 Kitware, Inc.
# Copyright 2009 Mathieu Malaterre <mathieu.malaterre@gmail.com>
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distributed this file outside of CMake, substitute the full
#  License text for the above reference.)

SET(SWIG_CXX_EXTENSION "cxx")
SET(SWIG_EXTRA_LIBRARIES "")

SET(SWIG_PYTHON_EXTRA_FILE_EXTENSION "py")

#
# For given swig module initialize variables associated with it
#
MACRO(SWIG_MODULE_INITIALIZE name language)
  STRING(TOUPPER "${language}" swig_uppercase_language)
  STRING(TOLOWER "${language}" swig_lowercase_language)
  SET(SWIG_MODULE_${name}_LANGUAGE "${swig_uppercase_language}")
  SET(SWIG_MODULE_${name}_SWIG_LANGUAGE_FLAG "${swig_lowercase_language}")

  IF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xUNKNOWNx$")
    MESSAGE(FATAL_ERROR "SWIG Error: Language \"${language}\" not found")
  ENDIF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xUNKNOWNx$")

  SET(SWIG_MODULE_${name}_REAL_NAME "${name}")
  IF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xPYTHONx$")
    # when swig is used without the -interface it will produce in the module.py
    # a 'import _modulename' statement, which implies having a corresponding 
    # _modulename.so (*NIX), _modulename.pyd (Win32).
    SET(SWIG_MODULE_${name}_REAL_NAME "_${name}")
  ENDIF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xPYTHONx$")
  IF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xPERLx$")
    SET(SWIG_MODULE_${name}_EXTRA_FLAGS "-shadow")
  ENDIF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xPERLx$")
ENDMACRO(SWIG_MODULE_INITIALIZE)

#
# For a given language, input file, and output file, determine extra files that
# will be generated. This is internal swig macro.
#

MACRO(SWIG_GET_EXTRA_OUTPUT_FILES language outfiles generatedpath infile)
  GET_SOURCE_FILE_PROPERTY(SWIG_GET_EXTRA_OUTPUT_FILES_module_basename
    ${infile} SWIG_MODULE_NAME)
  IF(SWIG_GET_EXTRA_OUTPUT_FILES_module_basename STREQUAL "NOTFOUND")
    GET_FILENAME_COMPONENT(SWIG_GET_EXTRA_OUTPUT_FILES_module_basename "${infile}" NAME_WE)
  ENDIF(SWIG_GET_EXTRA_OUTPUT_FILES_module_basename STREQUAL "NOTFOUND")
  FOREACH(it ${SWIG_${language}_EXTRA_FILE_EXTENSION})
    SET(${outfiles} ${${outfiles}}
      "${generatedpath}/${SWIG_GET_EXTRA_OUTPUT_FILES_module_basename}.${it}")
  ENDFOREACH(it)
ENDMACRO(SWIG_GET_EXTRA_OUTPUT_FILES)

#
# Take swig (*.i) file and add proper custom commands for it
#
MACRO(SWIG_ADD_SOURCE_TO_MODULE name outfiles infile)
  SET(swig_full_infile ${infile})
  GET_FILENAME_COMPONENT(swig_source_file_path "${infile}" PATH)
  GET_FILENAME_COMPONENT(swig_source_file_name_we "${infile}" NAME_WE)
  GET_SOURCE_FILE_PROPERTY(swig_source_file_generated ${infile} GENERATED)
  GET_SOURCE_FILE_PROPERTY(swig_source_file_cplusplus ${infile} CPLUSPLUS)
  GET_SOURCE_FILE_PROPERTY(swig_source_file_flags ${infile} SWIG_FLAGS)
  IF("${swig_source_file_flags}" STREQUAL "NOTFOUND")
    SET(swig_source_file_flags "")
  ENDIF("${swig_source_file_flags}" STREQUAL "NOTFOUND")
  SET(swig_source_file_fullname "${infile}")
  IF(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_SOURCE_DIR}")
    STRING(REGEX REPLACE 
      "^${CMAKE_CURRENT_SOURCE_DIR}" ""
      swig_source_file_relative_path
      "${swig_source_file_path}")
  ELSE(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_SOURCE_DIR}")
    IF(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_BINARY_DIR}")
      STRING(REGEX REPLACE 
        "^${CMAKE_CURRENT_BINARY_DIR}" ""
        swig_source_file_relative_path
        "${swig_source_file_path}")
      SET(swig_source_file_generated 1)
    ELSE(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_BINARY_DIR}")
      SET(swig_source_file_relative_path "${swig_source_file_path}")
      IF(swig_source_file_generated)
        SET(swig_source_file_fullname "${CMAKE_CURRENT_BINARY_DIR}/${infile}")
      ELSE(swig_source_file_generated)
        SET(swig_source_file_fullname "${CMAKE_CURRENT_SOURCE_DIR}/${infile}")
      ENDIF(swig_source_file_generated)
    ENDIF(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_BINARY_DIR}")
  ENDIF(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_SOURCE_DIR}")

  SET(swig_generated_file_fullname
    "${CMAKE_CURRENT_BINARY_DIR}")
  IF(swig_source_file_relative_path)
    SET(swig_generated_file_fullname
      "${swig_generated_file_fullname}/${swig_source_file_relative_path}")
  ENDIF(swig_source_file_relative_path)
  # If CMAKE_SWIG_OUTDIR was specified then pass it to -outdir
  IF(CMAKE_SWIG_OUTDIR)
    SET(swig_outdir ${CMAKE_SWIG_OUTDIR})
    # it may not exist, so create it:
    file(MAKE_DIRECTORY ${CMAKE_SWIG_OUTDIR})
  ELSE(CMAKE_SWIG_OUTDIR)
    SET(swig_outdir ${CMAKE_CURRENT_BINARY_DIR})
  ENDIF(CMAKE_SWIG_OUTDIR)
  SWIG_GET_EXTRA_OUTPUT_FILES(${SWIG_MODULE_${name}_LANGUAGE}
    swig_extra_generated_files
    "${swig_outdir}"
    "${infile}")
  SET(swig_generated_file_fullname
    "${swig_generated_file_fullname}/${swig_source_file_name_we}")
  # add the language into the name of the file (i.e. TCL_wrap)
  # this allows for the same .i file to be wrapped into different languages
  SET(swig_generated_file_fullname
    "${swig_generated_file_fullname}${SWIG_MODULE_${name}_LANGUAGE}_wrap")

  IF(swig_source_file_cplusplus)
    SET(swig_generated_file_fullname
      "${swig_generated_file_fullname}.${SWIG_CXX_EXTENSION}")
  ELSE(swig_source_file_cplusplus)
    SET(swig_generated_file_fullname
      "${swig_generated_file_fullname}.c")
  ENDIF(swig_source_file_cplusplus)

  #MESSAGE("Full path to source file: ${swig_source_file_fullname}")
  #MESSAGE("Full path to the output file: ${swig_generated_file_fullname}")
  GET_DIRECTORY_PROPERTY(cmake_include_directories INCLUDE_DIRECTORIES)
  SET(swig_include_dirs)
  FOREACH(it ${cmake_include_directories})
    SET(swig_include_dirs ${swig_include_dirs} "-I${it}")
  ENDFOREACH(it)

  SET(swig_special_flags)
  # default is c, so add c++ flag if it is c++
  IF(swig_source_file_cplusplus)
    SET(swig_special_flags ${swig_special_flags} "-c++")
  ENDIF(swig_source_file_cplusplus)
  SET(swig_extra_flags)
  IF(SWIG_MODULE_${name}_EXTRA_FLAGS)
    SET(swig_extra_flags ${swig_extra_flags} ${SWIG_MODULE_${name}_EXTRA_FLAGS})
  ENDIF(SWIG_MODULE_${name}_EXTRA_FLAGS)
  ADD_CUSTOM_COMMAND(
    OUTPUT "${swig_generated_file_fullname}" ${swig_extra_generated_files}
    COMMAND "${SWIG_EXECUTABLE}"
    ARGS "-${SWIG_MODULE_${name}_SWIG_LANGUAGE_FLAG}"
    ${swig_source_file_flags}
    ${CMAKE_SWIG_FLAGS}
    -outdir ${swig_outdir}
    ${swig_special_flags}
    ${swig_extra_flags}
    ${swig_include_dirs}
    -o "${swig_generated_file_fullname}"
    "${swig_source_file_fullname}"
    MAIN_DEPENDENCY "${swig_source_file_fullname}"
    DEPENDS ${SWIG_MODULE_${name}_EXTRA_DEPS}
    COMMENT "Swig source") 
  SET_SOURCE_FILES_PROPERTIES("${swig_generated_file_fullname}" ${swig_extra_generated_files}
    PROPERTIES GENERATED 1)
  SET(${outfiles} "${swig_generated_file_fullname}" ${swig_extra_generated_files})
ENDMACRO(SWIG_ADD_SOURCE_TO_MODULE)

#
# Create Swig module
#
MACRO(SWIG_ADD_MODULE name language)
  SWIG_MODULE_INITIALIZE(${name} ${language})
  SET(swig_dot_i_sources)
  SET(swig_other_sources)
  FOREACH(it ${ARGN})
    IF(${it} MATCHES ".*\\.i$")
      SET(swig_dot_i_sources ${swig_dot_i_sources} "${it}")
    ELSE(${it} MATCHES ".*\\.i$")
      SET(swig_other_sources ${swig_other_sources} "${it}")
    ENDIF(${it} MATCHES ".*\\.i$")
  ENDFOREACH(it)

  SET(swig_generated_sources)
  FOREACH(it ${swig_dot_i_sources})
    SWIG_ADD_SOURCE_TO_MODULE(${name} swig_generated_source ${it})
    SET(swig_generated_sources ${swig_generated_sources} "${swig_generated_source}")
  ENDFOREACH(it)
  GET_DIRECTORY_PROPERTY(swig_extra_clean_files ADDITIONAL_MAKE_CLEAN_FILES)
  SET_DIRECTORY_PROPERTIES(PROPERTIES
    ADDITIONAL_MAKE_CLEAN_FILES "${swig_extra_clean_files};${swig_generated_sources}")
  ADD_LIBRARY(${SWIG_MODULE_${name}_REAL_NAME}
    MODULE
    ${swig_generated_sources}
    ${swig_other_sources})
  STRING(TOLOWER "${language}" swig_lowercase_language)
  IF ("${swig_lowercase_language}" STREQUAL "java")
    IF (APPLE)
        # In java you want:
        #      System.loadLibrary("LIBRARY");
        # then JNI will look for a library whose name is platform dependent, namely
        #   MacOS  : libLIBRARY.jnilib
        #   Windows: LIBRARY.dll
        #   Linux  : libLIBRARY.so
        SET_TARGET_PROPERTIES (${SWIG_MODULE_${name}_REAL_NAME} PROPERTIES SUFFIX ".jnilib")
      ENDIF (APPLE)
  ENDIF ("${swig_lowercase_language}" STREQUAL "java")
  IF ("${swig_lowercase_language}" STREQUAL "python")
    # this is only needed for the python case where a _modulename.so is generated
    SET_TARGET_PROPERTIES(${SWIG_MODULE_${name}_REAL_NAME} PROPERTIES PREFIX "")
    # Python extension modules on Windows must have the extension ".pyd"
    # instead of ".dll" as of Python 2.5.  Older python versions do support
    # this suffix.
    # http://docs.python.org/whatsnew/ports.html#SECTION0001510000000000000000
    # <quote>
    # Windows: .dll is no longer supported as a filename extension for extension modules.
    # .pyd is now the only filename extension that will be searched for.
    # </quote>
    IF(WIN32 AND NOT CYGWIN)
      SET_TARGET_PROPERTIES(${SWIG_MODULE_${name}_REAL_NAME} PROPERTIES SUFFIX ".pyd")
    ENDIF(WIN32 AND NOT CYGWIN)
  ENDIF ("${swig_lowercase_language}" STREQUAL "python")
ENDMACRO(SWIG_ADD_MODULE)

#
# Like TARGET_LINK_LIBRARIES but for swig modules
#
MACRO(SWIG_LINK_LIBRARIES name)
  IF(SWIG_MODULE_${name}_REAL_NAME)
    TARGET_LINK_LIBRARIES(${SWIG_MODULE_${name}_REAL_NAME} ${ARGN})
  ELSE(SWIG_MODULE_${name}_REAL_NAME)
    MESSAGE(SEND_ERROR "Cannot find Swig library \"${name}\".")
  ENDIF(SWIG_MODULE_${name}_REAL_NAME)
ENDMACRO(SWIG_LINK_LIBRARIES name)

