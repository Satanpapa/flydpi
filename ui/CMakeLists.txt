cmake_minimum_required(VERSION 3.24)
project(FlyDPIUI LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick Network)
qt_standard_project_setup()

qt_add_executable(flydpi-ui
    qt/main.cpp
    qt/RpcClient.cpp
    qt/RpcClient.h
    qml.qrc
)

target_link_libraries(flydpi-ui PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Network
)
