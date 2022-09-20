# Scripts for converting between different spectroscopic file and data formats

## Extract raw intensities from a Eppendorf Realplex Mastercycler qPCR device

A perl script that processes the OdEvent log files continuously produced by the 
instrument and extracts the raw fluorescence detected recorded for each of the bins, along with temperature
and time.

Note: New OdEvent files are created by the instrument each day and are only retained for a few days.

For multi-day assays the files from two sequential days need to be concatenated.

Usage: distillEppendorph-v4.pl <OdEvent_filename>

Find the perlscript [here](distillEppendorph-v4.pl)
