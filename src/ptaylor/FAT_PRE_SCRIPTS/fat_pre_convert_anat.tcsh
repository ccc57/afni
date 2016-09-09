#!/bin/tcsh -ef

set version = "2.1"
set rev_dat = "Aug, 2016"

set here     = $PWD
set there    = ""
set anat_dir = ""
set ori_new  = "RPI"
set the_t1   = "anat.nii"

# ------------------- process options, a la rr ----------------------

if ( $#argv == 0 ) goto SHOW_HELP

set ac = 1
while ( $ac <= $#argv )
    # terminal options
    if ( ("$argv[$ac]" == "-h" ) || ("$argv[$ac]" == "-help" )) then
        goto SHOW_HELP
    endif
    if ( "$argv[$ac]" == "-ver" ) then
        goto SHOW_VERSION
    endif

   # required
   if ( "$argv[$ac]" == "-indir" ) then
      if ( $ac >= $#argv ) goto FAIL_MISSING_ARG
      @ ac += 1
      set there = "$argv[$ac]"

   else if ( "$argv[$ac]" == "-outdir" ) then
      if ( $ac >= $#argv ) goto FAIL_MISSING_ARG
      @ ac += 1
      set anat_dir = "$argv[$ac]"

   else if ( "$argv[$ac]" == "-orient" ) then
      if ( $ac >= $#argv ) goto FAIL_MISSING_ARG
      @ ac += 1
      set ori_new = "$argv[$ac]"

   else if ( "$argv[$ac]" == "-prefix" ) then
      if ( $ac >= $#argv ) goto FAIL_MISSING_ARG
      @ ac += 1
      set the_t1 = "$argv[$ac]"

   else
      echo "** unexpected option #$ac = '$argv[$ac]'"
      exit 2

   endif
   @ ac += 1
end

# =======================================================================
# ============================ ** SETUP ** ==============================
# =======================================================================

echo "++ Start script version: $version"

# ============================= dicom dir ===============================

if ( $there == "" ) then
    echo "** ERROR: need to input DICOM directory, after '-indir':"
    exit
endif

if ( ! -e "$there" ) then
    echo "\n** ERROR: can't find input DICOM directory: $there !"
    exit
endif

# ============================= input dir ===============================

# check for old relics

cd $there

printf "++ Checking $PWD for preexisting NIFTIs ... "

if ( (`find . -maxdepth 1 -type f -name "*nii" | wc -l` > 0 ) || \
     (`find . -maxdepth 1 -type f -name "*nii.gz" | wc -l` > 0 ) ) then
    echo "\n** ERROR: already some NIFTI files in $there !"
    exit
endif

cd $here 

# ============================= output dir ==============================

# check output directory, use default if nec

# default output dir, if nothing input.
if ( $anat_dir == "" ) then

    cd $here
    cd $there

    # designate full path
    set anat_dir = "$PWD/../ANATOM"
    echo "\n++ No output directory specificied by the user."
    echo "++ Using default location/naming output directory:"
    echo "\t$PWD"

    cd $here

endif

if ( -e "$anat_dir" ) then
    echo "\n+* WARNING: already some output directory $anat_dir"
endif

# =======================================================================
# =========================== ** PROCESS ** =============================
# =======================================================================

# ======================== convert dicoms ===============================

if ( ! -e $anat_dir ) then
    mkdir $anat_dir
endif
if ( ! -e $anat_dir/__TEMP_CONV_123 ) then
    mkdir $anat_dir/__TEMP_CONV_123
else
    echo "** ERROR: directory $anat_dir/__TEMP_CONV_123/ already exists!"
    echo "   -> confusion happens with converting repeats into same dir!"
    goto EXIT
endif

dcm2nii -o "$anat_dir/__TEMP_CONV_123" $there/*

# ================ clean up possible extraneous files ===================

cd $anat_dir/__TEMP_CONV_123

set all_t1 = `ls 2*.nii.gz`

# =========== put into proper orientation, simplify name =================

if ( ${#all_t1} < "1" ) then
    echo "\n** ERROR: no anatomical found"
    echo "\t(at least not with expected filename '2*')\n"
    goto EXIT
else if ( ${#all_t1} >= "2" ) then
    echo "\n+* Warning: multiple possible volumes: just choosing first (?!?).\n"
endif

3dresample                                        \
    -orient $ori_new                              \
    -inset  $all_t1[1]                            \
    -prefix ../$the_t1                            \
    -overwrite

# put (0, 0, 0) at center of mass.  (Aug, 2016)
3dCM -automask -set 0 0 0 ../$the_t1

cd $here 

set check = `3dinfo "$anat_dir/$the_t1"`
#echo "$#check"
if ( "$#check" >= "0" ) then
    echo "\nAll done!"
    cd $anat_dir
    echo "\nYour output anatomical is:\n\t$PWD/$the_t1\n"
    cd $here
else 
    echo "Whoa, badness outputting: $anat_dir/$the_t1"
endif

goto EXIT

# ========================================================================
# ========================================================================

SHOW_HELP:
cat << EOF
-------------------------------------------------------------------------
    The purpose of this function is to help convert an anatomical data
    set from DICOM files into a volume.  Ummm, yep, that's about it.

    (But it will be done in a way to fit in line with other
    processing, particularly with DTI analysis, so it might not be
    *totally* useless; more options while converting might be added
    over time, as well.)

    REQUIRES: AFNI, dcm2nii.

    Ver. $version (PA Taylor, ${rev_dat})

-------------------------------------------------------------------------

  RUNNING:

  \$ fat_pre_convert_anat.tcsh                 \
        -indir   DIR_IN                       \
        {-outdir DIR_OUT}                     \
        {-prefix PREFIX}                      \
        {-orient ORIENT} 

  where:
    -indir  DIR_IN  :required input directory; DIR_IN should contain
                     only DICOM files; all will be selected.

    -outdir DIR_OUT :optional output directory (default is called
                     'ANATOM', placed parallel to DIR_IN).
    -prefix PREFIX  :optional output file prefix for volume in DIR_OUT
                     (default is called '$the_t1').

    -orient ORIENT  :option to choose the orientation of the output 
                     volume (default is RPI).
        
-------------------------------------------------------------------------

  OUTPUTS: a single anatomical volume in the DIR_OUT.  
           In some cases of anatomical volume acquisition, the DICOMS
           get converted to more than one format of volumetric output
           (one total acquired volume, one centered around the head,
           etc.); these usually have different formats of file name,
           starting with '2*', 'co*' and 'o*'.  Basically, the '2*' is
           chosen for outputting, and the others are stored in a
           subdirectory called DIR_OUT/__TEMP_CONV_123/.

-------------------------------------------------------------------------

  EXAMPLE:

  \$ fat_pre_convert_anat.tcsh                \
       -indir  "ANAT_DICOMS"                 \
       -orient RAI
    
-------------------------------------------------------------------------

EOF
    goto EXIT

SHOW_VERSION:
   echo "version  $version (${rev_dat})"
   goto EXIT

# send everyone here, in case there is any cleanup to do
EXIT:
   exit
