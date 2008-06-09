!-----------------------------------------------------------------------------------!
! Bader charge density analysis program
! Version 0.25 (06/09/08)
!
! Authors:
!   Wenjie Tang, Andri Arnaldsson, and Graeme Henkelman
!
! Contributers:
!   Johannes Voss (DTU)
!
! Based on algorithms described in the following publications:
!
!   A fast and robust algorithm for Bader decomposition of charge density,
!   G. Henkelman, A. Arnaldsson, and H. Jonsson,
!   Comput. Mater. Sci. 36 254-360 (2006).
!
!   An improved grid-based algorithm for Bader charge allocation
!   E. Sanville, S. Kenny, R. Smith, and G. Henkelman
!   J. Comput. Chem. 28 899-908 (2007).
!
!   A grid-based Bader analysis algorithm without lattice bias
!   W. Tang, E. Sanville, and G. Henkelman
!   J. Phys.: Condens. Matter (in press, 2008)
!
!-----------------------------------------------------------------------------------!

  PROGRAM Charge

     USE options_mod
     USE ions_mod
     USE charge_mod
     USE io_mod
     USE bader_mod 
     USE voronoi_mod
     USE chgcar_mod
     
     IMPLICIT NONE

     ! Variables
     TYPE(options_obj) :: opts
     TYPE(ions_obj) :: ions
     TYPE(charge_obj) :: chgval
     TYPE(bader_obj) :: bdr
     TYPE(voronoi_obj) :: vor
 
    ! Write the version number
     WRITE(*,'(/,2X,A)') 'GRID BASED BADER ANALYSIS  (v0.25 06/09/08)'

     ! Get the control variables
     CALL get_options(opts)

     ! Call the read routines from io_mod
     CALL read_charge(ions,chgval,opts)

     IF (opts%bader_flag) THEN
       CALL bader_calc(bdr,ions,chgval,opts)
       CALL bader_mindist(bdr,ions,chgval)
       CALL bader_output(bdr,ions,chgval)
     END IF
       IF (opts%print_all_bader==1)  CALL write_all_bader(bdr,opts,ions,chgval)
       IF (opts%print_all_atom==1)   CALL write_all_atom(bdr,opts,ions,chgval)
       IF (opts%print_sel_atom==1)   CALL write_sel_atom(bdr,opts,ions,chgval)
       IF (opts%print_sel_bader==1)  CALL write_sel_bader(bdr,opts,ions,chgval)
       IF (opts%print_bader_index==1) CALL write_bader_index(bdr,opts,ions,chgval)
       IF ( opts%print_atom_index==1) CALL write_atom_index(bdr,opts,ions,chgval)

!     IF (opts%dipole_flag) CALL multipole()
     IF (opts%voronoi_flag) CALL voronoi(vor,ions,chgval)

    WRITE(*,*)
  END PROGRAM Charge

