cmake_minimum_required(VERSION 3.21)
project(OPCEFIntegration LANGUAGES C CXX OBJCXX)
set(CEF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../OP-CEF-Prototype/third_party/cef" CACHE PATH "Pinned CEF binary distribution")
get_filename_component(CEF_ROOT "${CEF_ROOT}" ABSOLUTE)
list(APPEND CMAKE_MODULE_PATH "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)
if(NOT OS_MAC OR NOT PROJECT_ARCH STREQUAL "arm64" OR NOT USE_SANDBOX)
  message(FATAL_ERROR "This integration requires macOS arm64 and sandbox ON")
endif()
file(READ "${CEF_ROOT}/include/cef_version.h" CEF_VERSION_HEADER)
if(NOT CEF_VERSION_HEADER MATCHES "154.0.34\\+g14c5a08\\+chromium-154.0.8037.98")
  message(FATAL_ERROR "CEF version differs from version.lock.json; review the upgrade contract first")
endif()
set(CMAKE_OSX_DEPLOYMENT_TARGET 12.0)
add_subdirectory(${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)
set(OP_BUNDLE_ID "local.personal.OP.CEFIntegration" CACHE STRING "Isolated product bundle identity")
set(OP_PRODUCT_NAME "OP CEF Integration" CACHE STRING "Native product display name")
set(CEF_TARGET OPCEFIntegration)
SET_CEF_TARGET_OUT_DIR()
set(CEF_APP "${CEF_TARGET_OUT_DIR}/${CEF_TARGET}.app")
set(OP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
set(EXECUTABLE_NAME "${CEF_TARGET}")
set(PRODUCT_NAME "${OP_PRODUCT_NAME}")
file(GLOB NATIVE_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/Native/*.swift")
set(SHARED_SOURCES "${OP_ROOT}/ChatGPTNative/Services/SnapshotModels.swift" "${OP_ROOT}/ChatGPTNative/Services/SnapshotStore.swift" "${OP_ROOT}/ChatGPTNative/Services/SnapshotLibrary.swift" "${OP_ROOT}/ChatGPTNative/Views/RecoveryView.swift")
set(NATIVE_LIB "${CMAKE_CURRENT_BINARY_DIR}/libOPNative.dylib")
add_custom_command(OUTPUT "${NATIVE_LIB}"
 COMMAND xcrun swiftc -O -swift-version 6 -target arm64-apple-macos14.0 -emit-library -module-name OPNative
 -import-objc-header "${CMAKE_CURRENT_SOURCE_DIR}/Runtime/Bridge.h"
 -framework AppKit -framework SwiftUI -framework Security -framework UserNotifications -lsqlite3 -Xlinker -undefined -Xlinker dynamic_lookup
 -Xlinker -install_name -Xlinker @executable_path/../Frameworks/libOPNative.dylib
 ${NATIVE_SOURCES} ${SHARED_SOURCES} -o "${NATIVE_LIB}"
 DEPENDS ${NATIVE_SOURCES} ${SHARED_SOURCES} Runtime/Bridge.h VERBATIM)
add_custom_target(OPNative DEPENDS "${NATIVE_LIB}")
list(APPEND CEF_COMPILER_FLAGS -fobjc-arc)
add_executable(${CEF_TARGET} MACOSX_BUNDLE Runtime/Runtime.mm)
SET_EXECUTABLE_TARGET_PROPERTIES(${CEF_TARGET})
add_dependencies(${CEF_TARGET} libcef_dll_wrapper OPNative)
target_link_options(${CEF_TARGET} PRIVATE -Wl,-export_dynamic)
target_link_libraries(${CEF_TARGET} libcef_dll_wrapper ${CEF_STANDARD_LIBS} "${NATIVE_LIB}")
set_target_properties(${CEF_TARGET} PROPERTIES XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${OP_BUNDLE_ID}" MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist.in")
add_custom_command(TARGET ${CEF_TARGET} POST_BUILD COMMAND python3 "${CMAKE_CURRENT_SOURCE_DIR}/package-framework.py" "${CEF_BINARY_DIR}/Chromium Embedded Framework.framework" "${CEF_APP}/Contents/Frameworks/Chromium Embedded Framework.framework" VERBATIM)
foreach(_suffix_list ${CEF_HELPER_APP_SUFFIXES})
 string(REPLACE ":" ";" _suffix_list ${_suffix_list})
 list(GET _suffix_list 0 _name_suffix)
 list(GET _suffix_list 1 _target_suffix)
 list(GET _suffix_list 2 _plist_suffix)
 # OP uses its native UserNotifications channel; do not register a CEF Alerts app.
 if(_target_suffix STREQUAL "_alerts")
   continue()
 endif()
 set(_helper_target "OPCEFIntegration_Helper${_target_suffix}")
 set(_helper_output_name "OPCEFIntegration Helper${_name_suffix}")
 file(READ "${CMAKE_CURRENT_SOURCE_DIR}/Resources/helper-Info.plist.in" _plist_contents)
 string(REPLACE "\${EXECUTABLE_NAME}" "${_helper_output_name}" _plist_contents "${_plist_contents}")
 string(REPLACE "\${PRODUCT_NAME}" "${_helper_output_name}" _plist_contents "${_plist_contents}")
 string(REPLACE "\${OP_BUNDLE_ID}" "${OP_BUNDLE_ID}" _plist_contents "${_plist_contents}")
 string(REPLACE "\${BUNDLE_ID_SUFFIX}" "${_plist_suffix}" _plist_contents "${_plist_contents}")
 string(REPLACE "\${VERSION_SHORT}" "0.3.4" _plist_contents "${_plist_contents}")
 file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/helper${_target_suffix}.plist" "${_plist_contents}")
 add_executable(${_helper_target} MACOSX_BUNDLE Runtime/Helper.cc)
 SET_EXECUTABLE_TARGET_PROPERTIES(${_helper_target})
 add_dependencies(${_helper_target} libcef_dll_wrapper)
 target_link_libraries(${_helper_target} libcef_dll_wrapper ${CEF_STANDARD_LIBS})
 set_target_properties(${_helper_target} PROPERTIES XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${OP_BUNDLE_ID}.helper${_plist_suffix}" MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/helper${_target_suffix}.plist" OUTPUT_NAME "${_helper_output_name}")
 add_dependencies(${CEF_TARGET} ${_helper_target})
 add_custom_command(TARGET ${CEF_TARGET} POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_directory "${CEF_TARGET_OUT_DIR}/${_helper_output_name}.app" "${CEF_APP}/Contents/Frameworks/${_helper_output_name}.app" VERBATIM)
endforeach()
add_custom_command(TARGET ${CEF_TARGET} POST_BUILD
 # Remove stale output when rebuilding a directory that previously packaged Alerts.
 COMMAND ${CMAKE_COMMAND} -E rm -rf "${CEF_APP}/Contents/Frameworks/OPCEFIntegration Helper (Alerts).app"
 COMMAND ${CMAKE_COMMAND} -E make_directory "${CEF_APP}/Contents/Resources"
 COMMAND ${CMAKE_COMMAND} -E copy "${NATIVE_LIB}" "${CEF_APP}/Contents/Frameworks/libOPNative.dylib"
 COMMAND python3 "${CMAKE_CURRENT_SOURCE_DIR}/compose-observer.py" "${OP_ROOT}/ChatGPTNative/Services/MessageObserver.js" "${CEF_APP}/Contents/Resources/CEFObserver.js"
 COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/Runtime/ExecutionQuery.js" "${CEF_APP}/Contents/Resources/ExecutionQuery.js"
 COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/Runtime/ReplyCompletion.js" "${CEF_APP}/Contents/Resources/ReplyCompletion.js"
 COMMAND python3 "${CMAKE_CURRENT_SOURCE_DIR}/package-icon.py" "${OP_ROOT}/ChatGPTNative/Assets.xcassets/AppIcon.appiconset" "${CEF_APP}/Contents/Resources/OP.icns"
 COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/Resources/LICENSE-CEF.txt" "${CEF_APP}/Contents/Resources/LICENSE-CEF.txt"
 COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Header" "${CEF_APP}/Contents/Resources/Header"
 VERBATIM)
PRINT_CEF_CONFIG()
