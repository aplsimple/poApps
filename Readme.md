# What's that

This is a fork of *poApps* developed and maintained by [Paul Obermeier](http://www.posoft.de/contact.html).

The only purpose of this fork is to provide the comparison of directories by lists.

Read the original Readme-orig.txt describing poApps.

For further details, visit [http://www.posoft.de/](http://www.posoft.de).

# How's that

The fork provides the comparison of directories by their lists.

The directories' lists are kept in two files having *.podiff* extension. Their contents are compared as appropriate directories line by line. See for example *1.podiff* and *2.podiff* files.

**Note:** the list files can contain comments and empty lines, but all the rest of lines should correspond to each other, line number by line number, being the directory names to compare.

While *poApps/dirDiff* application running, enter the list files' names in the two top entries and press Enter key. Then press F5 key to compare the directories of those list files. Never mind the red signs about the *.podiff* files, it's only about them not being directories.

Thus, you compare a batch of directories which may depend on each other in various combinations.

You'll find it convenient to merge your saved prior sessions into the two *.podiff* files, for this "all in one" session to be saved as well.

As a small bonus, the fork allows to select a color scheme of *poApps* application.

# How to run

Unpack the fork into a directory. Then try and run the command in a console:

`
tclsh poApps.tcl
`

If you get an error message, it's highly likely about a package not installed. In Windows, the installation of [ActiveTcl 8.6](https://www.activestate.com/products/tcl/downloads/) should suffice. In Linux, try and install that absent package, then repeat `tclsh poApps.tcl`.


To change a color scheme of *poApps*, run it with options:

  * `--cs nn` where `nn` means a color scheme; may be from `-2` to `47`
  * `--hue nn` where `nn` means a hue; may be from `-99` to `99`
  
For example:

`
tclsh poApps.tcl -cs 21 -hue 25
`

-------------

# Restriction

In this mode, you can not copy nor move the "only" files because of their directories' discrepancy. An attempt to do this results in a Tcl error message.

You can copy or move only the "different left / right" files.
