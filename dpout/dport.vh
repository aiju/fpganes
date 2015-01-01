`timescale 1ns / 1ps
`default_nettype none

`define symK(a,b) ((b)<<5|(a))
`define symBS `symK(28, 5)
`define symBE `symK(27, 7)
`define symSS `symK(28, 2)
`define symSE `symK(29, 7)
`define symFS `symK(30, 7)
`define symFE `symK(23, 7)
`define symSR `symK(28, 0)
`define ATTRMAX 207
