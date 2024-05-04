poApps is a collection of several applications in one starpack.
It is available for Windows, Linux and Mac OS X.

poApps currently contains the following applications:
  - poImgview:   Image viewer with image processing capabilities. 
  - poImgBrowse: Image browser.
  - poBitmap:    Bitmap editor to manipulate X-Window bitmaps.
  - poSlideShow: Slide show.
  - poImgdiff:   Image comparison.
  - poDiff:      Directory comparison.
  - tkdiff:      File comparison.
  - poPresMgr:   PowerPoint presentation manager.
  - poOffice:    Office utilities.

poApps is copyrighted by Paul Obermeier and distributed as free software.
You may use it for private or commercial purposes, but without warranty.
Note, that tkdiff is not developed by Paul Obermeier, but a slightly modified 
tkdiff version is included for convenience.

The poApps homepage is at http://www.posoft.de/

Note, that poApps can be used as a graphical application by clicking on
it's icon or from a shell/command window in batch mode.
  - To use poApps in batch mode on Windows, use the poAppsBatch.exe version.
  - To use poApps in batch mode on Mac OS X, copy the executable 
    (contained in folder Contents/MacOS of the poApps.app package)
    into a folder listed in your PATH environment variable.

Release history:
================

2.12.0  2023/08/20
    Added new application poClipboardViewer.

    Improved handling of clipboard content on Windows.
    Adjusted toolbar images according to display scale settings.
    Added theme selection possibility.
    Adaptions for Tcl9 readiness.

    All apps:
        Miscellaneous bug fixes and improvements.

    poTcllib:
        Improved image file detection in module poType.tcl.
        Miscellaneous bug fixes and improvements.
        Removed calls to procedures in poApps namespace, so poTcllib is
        useable without main application.

    poTklib:
        New module poWinClipboard.tcl.
        Miscellaneous bug fixes and improvements.
        Removed calls to procedures in poApps namespace, so poTklib is useable
        without main application.

    poDiff:
        Improved speed when immediate update is disabled.
        Added new command line options: --immediate --marknewer --marktypes

    poImgBrowse:
        Added "Copy as" functionality to use Windows clipboard with different file formats.
        Added file selection using shortcuts similar to Windows Explorer.

    poImgdiff:
        Pressing the left button in the canvas, prints position and colors into log window.

    poImgview:
        Added "Copy as" and "Paste from" functionality to use Windows clipboard with different file formats.
        Added menu to open clipboard viewer.
        Added rollup to add transparency by specifying a transparent color.
        Pressing the left button in the canvas, prints position and color into log window.
        
2.11.0  2022/11/25
    Added support for tablet mode.

    All apps:
        Added more Drag-and-Drop support.
        Added new RAW pixel types "int" and "double".
        Added new RAW option -skipbytes.

    poApps:
        Added options --gzip and --gziplevel to compress directories and files.

    poImgview:
        Added menu entry and toolbar button to show hexdump of image.

    poSlideShow:
        Added support for tablet mode.

2.10.0  2022/07/17
    Added PAWT to handle 16-bit and 32-bit images.

    All apps:
        Added test suite for batch processing.
        Corrected several bugs occuring in batch mode.
        Added Drag-and-Drop support in FileType settings window.

    poApps:
        Added support for system notifications.

    poDiff:
        Added options to create non-existent directories in context menu or when trying to diff.
        Clear list contents when selecting new session.
        Added notifications for long running jobs.

    poImgview:
    poImgdiff:
        Use new PAWT package to read and handle images with 16-bit or 32-bit values.

    poOffice:
        Added notifications for long running jobs.

    tkdiff:
        Added progress status messages for the two long lasting steps "Mark" and "Reassign".
        Comparison can now be cancelled by pressing the Escape key.


2.9.0   2022/04/15
    Added fitsTcl to handle FITS files as images.

    poApps:
        Added command line option "--main" to show main window on startup.
        Added checkbuttons to display message boxes on Exit, Error or Warning.

    poDiff:
        Added button to switch alignment of FileName columns.
        Added new compare mode "Exist", which only checks, 
          if files exist in left or right directory.
        Disable compare and search buttons after pressing.
        Clear file lists after selecting a session.

    poImgview:
        Added "Save in original directory" button and menu entry (like in IrfanView).
        Corrected bug, which did not allow to read multiple images via the command line.

    poImgdiff:
        Display file and image information in notebook tabs like in poDiff.

2.8.0   2021/12/26
    Added MuPDF to handle PDF files as images.

    poImgview:
    poImgdiff:
    poImgBrowse:
        Added handling of PDF files as images.
        Added handling of multi-page images.

    poOffice:
        Miscellaneous improvements.

2.7.0   2021/07/23
    Improved handling of Office tools
    
    poOffice:
        Major rewrite and additional functionality.
        Ability to embed Office application into a Tk frame.
    
    poBitmap:
    poImgview:
    poImgdiff:
        Only show image files in recently used menu.

2.6.2   2021/01/06
    Maintenance release

    poImgview:
        Added new command line option "--opt" to specify image format options.

    poDiff:
        Added context menu entries to select left and right diff files.
        Check for existence of EDITOR environment variable.

2.6.1   2020/09/04
    Maintenance release (not officially released)

    Miscellaneous bug fixes and improvements in poTcllib and poTklib.
    Better look and feel on Linux.

    poImgview:
        Added functionality to display inverse palette views.
        Added functionality to batch generate palette views.

2.6.0   2020/06/09
    Improved image handling functionality

    Potential incompatibility:
        Remove settings file poImgType.cfg before starting this version.

    Miscellaneous bug fixes and improvements in poTcllib and poTklib.

    All apps:
        Added ability to write and check configuration version.

    All image apps:
        Added new image format options introduced with Img 1.5.0.
        Added new module for parsing raw data from PPM files.

    poDiff:
        Added "Switch and diff" functionality reachable via Ctrl+Shift+T.
        Added descriptive text and background color to confirmation windows.

    poImgview:
        Added widgets to specify image resolution in DPI. Not yet active.
        Added functionality to display palette views.
          Currently supported palette files:
            Trian3DBuilder material XML files.
            CSV files with column layout as follows:
                # Index Red Green Blue Name
                0,72,154,0,Material_0

    poImgBrowse:
        Added columns to display horizontal and vertical DPI information.

    Updated external packages:
        Img       1.5.0

2.5.3   2020/05/02
    Maintenance release

    Miscellaneous bug fixes and improvements in poTcllib and poTklib.

    All apps:
        Improved checked widgets.

    poDiff:
        Fixed bug, which caused poDiff to be not responsive during directory comparison.

    poImgview:
        Improved speed of image loading, especially RAW images.
        Corrected display of current and total number of images in current directory.

    tkdiff:
        Only use text selected in one of the text widget as search string,
        not the clipboard content.

    Updated external packages:
        Img       1.4.10
        Tablelist 6.9
        Twapi     4.3.8

2.5.2   2020/03/08
    Maintenance release

    All apps:
        Use Tcl/Tk 8.6.10.
        Improved checked widgets.
        Extended list of Linux file browsers: konqueror, dolphin, nautilus.

    Updated external packages:
        scrollutil 1.5
        Tablelist  6.8

2.5.1   2019/11/23
    Maintenance release

    All apps:
        Bug fixes in SimpleTextEdit widget.

2.5.0   2019/11/03
    Graphical user interface improvements and extended functionality. 

    Potential incompatibility:
        Remove settings file poImgType.cfg before starting this version.

    Miscellaneous bug fixes and improvements in poTcllib and poTklib.

    All apps:
        Replaced autoscroll package with Csaba's new scrollutil package.
        Unified usage of status widget including progress bar.
        Improved combobox functionality: Key press selects entry in drop-down list.
        Improved and unified tk_getSaveFile usage.
        Extended drag and drop support.
        Extended functionality of SimpleTextEdit and Preview widget.

    poImgBrowse:
        Several improvements in graphical user interface.
        Added functionality to load selected images into PowerPoint.

    poImgdiff:
        Improved RAW image comparison.

    poImgview:
        Integrated test image generation functionality.

    poPresMgr:
        Added support for creating videos with PowerPoint.

    Updated external packages:
        CAWT       2.4.7
        scrollutil 1.2
        Tablelist  6.7
        tksvg      0.3

2.4.3   2019/08/13
    Maintenance release

    Miscellaneous bug fixes and improvements in poTcllib and poTklib.

    All apps:
        Corrected cleanup of temporary tclkit files.
        Improved handling of recent files and directories:
          Opening the menu was slow, if the number of rencent entries were large
          and/or contained network pathes.

    tkdiff:
        Fixed bug when opening the search window and the clipboard was empty.
        Use the diff.exe of the starpack, if no diff program is available in PATH.

2.4.2   2019/06/21
    Maintenance release

    All apps:
        Corrected batch processing.

    poImgview:
        Corrected limits of selection rectangle spinboxes. 

2.4.1   2019/06/08
    Maintenance release

    poImgview:
        Improved using current directory for saving images and starting the image browser. 

    poImgBrowse:
        Check, if a file name is an image file before trying to generate a thumbnail.
        Otherwise when having a large binary file (eg. ZIP), the photo command will crash.

2.4.0   2019/03/03
    Added support for FLIR FPF images.

    poTcllib/poType.tcl:
        Corrected detection of JPEG and SVG images.

    poTklib/poImgType.tcl:
        Corrected several read and write options.
        Caution: Remove poImgtype.cfg before starting poApps version 2.4.0.

    poTklib/poWinPreview.tcl:
        Corrected display of title when loading text content.
        
    All apps:
        Build session, last files and directories menus on demand using bitmaps.
        Added support for reading FLIR FPF images using Img 1.4.9.

    poDiff:
        More drag and drop support.

    poImgview:
        Added ability to scan through the images of current directory.
        Added key bindings for selection rectangle.
        Added ability to toggle image loading mode (load as new image vs. load over existing image)
        Better error detection when reading images.

    poImgBrowse:
        Added button for stopping file scanning.
        Add drag and drop support.

    Updated external packages:
        Tcl/Tk 8.6.9
        CAWT 2.4.3
        Img 1.4.9
        Tablelist 6.4
        Twapi 4.3.5

2.3.3   2018/12/27
    Maintenance release

    Miscellaneous bug fixes and improvements in poTcllib and poTklib.

    poDiff:
        Corrected replacement of multiple files.

    poImgview:
        Corrected reading of RAW images without header. 

    poImgBrowse:
        Major rewrite to improve scanning and browsing of images.
        Corrected sorting of width and height column.

    poSlideShow:
        Corrected starting of a slide show when calling SetInitialFile or SetFileMarkList.

    tkdiff:
        New adapted version based on tkdiff 4.3.5.

2.3.2   2018/04/26
    Maintenance release

    Miscellaneous bug fixes and improvements in poTcllib and poTklib.
    File and image type tab: Changed graphical layout to use a tablelist instead of a combobox.
    Improved RAW image handling. New command line option: --rawinfo

    poDiff:
        Sort results like Explorer: Directories first, then files.
        Added notebook containing Edit, Preview and FileInfo tabs in search window.

2.3.1   2017/12/30
    Maintenance release

    Miscellaneous bug fixes and improvements in poTcllib and poTklib.
    New experimental module poOffice with Outlook and Word utility tools.
    Added support for new Tcl/Tk 8.7 features:
        Display of image alpha values.
        Text in progress bars.

    poDiff:
        Better handling of files starting with a tilde (esp. Office temp. files: ~$xyz)
        Corrected comparison in mode IgnoreEndOfLineChars.
    poImgBrowse:
        Added ability for slide shows of directories.

    Updated external packages:
        Tcl/Tk 8.6.8
        CAWT 2.4.1
        Img 1.4.7
        Tablelist 6.0
        Twapi 4.2.12

2.3.0   2017/06/18
    Added drag-and-drop support and reading of SVG images.

    Use dictionary sort for all string and file lists.
    File selection windows (tk_getOpenFile, tk_getSaveFile) are now modal windows.
    poImgBrowse:
        Added last used directories in context menu for copy and move operations.
    poTcllib: 
        Added new module poMatrix for handling matrices represented as list of lists.
        New procedures in module poMisc: IsSquare IsPowerOfTwo AbsToRel PrintDict
                                         Distance2D Distance3D GetFileNumber ReplaceFileNumber
    poTklib:
        Added new module poDragAndDrop for handling tkdnd functionality.
        Added new module poUkazUtil implementing utility procedures for the ukaz widget.
        New procedures in module poTablelistUtil: GetNumRows GetNumCols GetCellValue SetCellValue
        Extended poDial functionality.

2.2.5   2016/12/11
    Maintenance release

    Added ability to batch compare 2 files.
    Added option to switch off text widget undo functionality for tablelist
      to work around an error introduced in Tcl 8.6.6.
    Several bug fixes and enhancements in poTcllib and poTklib.
    poDiff and poTkDiff:
        Added new command line options: --compare, --ignnoreeol, --ignorehour
    poImgview:
        Added ability view 16-bit RAW images in pseudo color.
    Updated external packages:
        Tcl/Tk 8.6.6
        CAWT 2.3.1
        Tablelist 5.16
        Twapi 4.2a3

2.2.4   2016/05/27
    Maintenance release

    Cleanup tclkit generated temporary directories on Windows.
    Several bug fixes in poTcllib and poTklib.
    poImgview and poImgBrowse:
        Img 1.4.6 fixes bug when reading PNG images regarding 
        gamma correction and 16-bit images.
    poSlideShow:
        Fixed memory leaks.
        Fullscreen mode now works correctly on Mac.
    Updated external packages:
        Img 1.4.6
        poImg 2.0.1

2.2.3   2016/04/17
    Maintenance release
    
    poImgview and poImgBrowse:
        Bugfixes regarding slideshows (path names with spaces, no images selected).
        Img 1.4.5 fixes bug when reading progressive JPEG images (Windows).
        Img 1.4.5 fixes slow "-format window" option when capturing a canvas (Windows).
    Tk 8.6.5 improves stability on Mac.
    Updated external packages:
        Tcl/Tk 8.6.5
        Img 1.4.5
        Tablelist 5.15

2.2.2   2015/11/05
    Enhanced batch processing functionality.

    poDiff:
        Added new command line option --filetype.
        Added combobox to search for given file types only.
    poImgview:
        Print selection rectangle to stdout when pressing right mouse button.

2.2.1   2015/10/10
    Enhanced batch processing functionality and bug fixes.

    poDiff:
        Added batch mode (enabled via --batch) for directory comparison.
        Added new command line option --convert.
        Added new command line option --filematch.
    Bug fixes in modules poWinSelect and poWinRollUp.
    Updated external packages: 
        Tablelist 5.14
        CAWT 2.1.0

2.2.0   2015/09/11
    Enhanced functionality and bug fixes.

    poDiff:
        Added ability to edit search and session lists.
        Added button to switch directories.
        Added --session command line parameter.
    poImgview: 
        Tools are now realized as rollups instead of simple toplevel windows.
        Added ability to manipulate selection rectangle history list.
        Improved ICO reader (correct sizes of sub-icons).
        Added --equalsize command line parameter.
    poImgdiff: 
        Improved support of RAW image files.
        Added button to switch image files.
    poSlideShow:
        Added interactive changing of text color, scale to fit, toggling of
        info message and image rotation.
    New module poWinRollUp implementing rollup widgets.
    Corrected bug starting tkdiff.
    Added build number and build date to poApps version information.
    Updated external packages: 
        Tablelist 5.13
        CAWT 2.0.0
        Img 1.4.3
        poImg 2.0.0.
    Internal restructuring:
        poImg is now compiled with TEA. 
        No VisualStudio runtime libraries needed on Windows.

2.1.0   2014/12/30
    Enhanced functionality and bug fixes.

    Added PowerPoint manager (poPresMgr) as new application.
    poImgview: Added slide show functionality.
    poImgview: Added color count functionality.
    poDiff: Use tablelists instead of simple listboxes.
    poDiff: Added progress bars in diff and search windows.
    poDiff: Added preview and file information tabs.
    poDiff: Added ability to search for files using date comparison.
    Added several new command line options.
    Miscellaneous bug fixes and improvements.
    Updated external packages: Tcl 8.6.3, CAWT 1.2.0, Tablelist 5.12.1.

2.0.4   2014/03/16
    Enhanced functionality and bug fixes.

    Added poSlideShow as new application.
    poImgview: Reworked GUI layout.
    poImgview: Display values of RAW images.
    poImgview: Added new window for interactive image composition.
    poBitmap: Added scale functionality. Speed improvements.
    Added functionality to edit recent files and directories list.
    Added several new command line options.
    Miscellaneous bug fixes and small improvements.

2.0.3   2013/12/08
    Enhanced functionality and bug fixes.

    Use of self-compiled tclkits.
    Reorganization of Open and Browse menus.
    MouseWheel event handling for all scrolled widgets.
    Image autofit in poImgview and poImgdiff.
    Unified image histogram display.
    poImgview: New command line option "--compose" to compose several
               images in batch mode.
    poImgview: New command line option "--crop" to crop images in batch mode.
    Added CAWT 1.0.4: Load histogram values to Excel. Excel diff in poDiff.
    Updated Tablelist to version 5.10.

2.0.2   2013/10/12
    Enhanced functionality and bug fixes. Windows 64-bit support.

    poImgdiff: Speed improvement when comparing images.
    poImgdiff: New command line option "--savehist" to save the 
               histograms in a CSV file.
    Improved heuristics when starting poApps with 1 directory as parameter.
    Settings menu now available on main page.
    Updated Img version to 1.4.2.

2.0.1   2013/09/08
    Enhanced functionality, rework and several bug fixes.

    Enhanced interoperability between the applications.
    New combine functionality in poImgview.
    Iconify main window when starting an application.
    Use tablelist widget for file and image information display.
    Elimination of duplicate code.

2.0.0   2013/07/14
    Major rewrite and packaging in one starpack.

    Put every standalone poTools into a namespace.
    Added (slightly modified) version of tkdiff.
    Use of Tcl 8.6.0 for starpacks.
    Enhanced interoperability between the applications.
    Incompatibility: Rework of configuration files.
