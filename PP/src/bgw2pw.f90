!
! Copyright (C) 2010-2012 Georgy Samsonidze
!
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
! Converts BerkeleyGW WFN and RHO files to the format of pw.x.
!
!-------------------------------------------------------------------------------
!
! BerkeleyGW, Copyright (c) 2011, The Regents of the University of
! California, through Lawrence Berkeley National Laboratory (subject to
! receipt of any required approvals from the U.S. Dept. of Energy).
! All rights reserved.
!
! Redistribution and use in source and binary forms, with or without
! modification, are permitted provided that the following conditions are
! met:
!
! (1) Redistributions of source code must retain the above copyright
! notice, this list of conditions and the following disclaimer.
!
! (2) Redistributions in binary form must reproduce the above copyright
! notice, this list of conditions and the following disclaimer in the
! documentation and/or other materials provided with the distribution.
!
! (3) Neither the name of the University of California, Lawrence
! Berkeley National Laboratory, U.S. Dept. of Energy nor the names of
! its contributors may be used to endorse or promote products derived
! from this software without specific prior written permission.
!
! THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
! "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
! LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
! A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
! OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
! SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
! LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
! DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
! THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
! (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
! OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
!
! You are under no obligation whatsoever to provide any bug fixes,
! patches, or upgrades to the features, functionality or performance of
! the source code ("Enhancements") to anyone; however, if you choose to
! make your Enhancements available either publicly, or directly to
! Lawrence Berkeley National Laboratory, without imposing a separate
! written license agreement for such Enhancements, then you hereby grant
! the following license: a  non-exclusive, royalty-free perpetual
! license to install, use, modify, prepare derivative works, incorporate
! into other computer software, distribute, and sublicense such
! enhancements or derivative works thereof, in binary and source code
! form.
!
!-------------------------------------------------------------------------------
!
! bgw2pw subroutines:
!
! write_evc - generates eigenvalues and wavefunctions in espresso format
! write_cd  - generates charge density in espresso format
! check_inversion - checks whether real/complex version is appropriate
!
!-------------------------------------------------------------------------------

PROGRAM bgw2pw

  USE environment, ONLY : environment_start, environment_end
  USE io_files, ONLY : prefix, tmp_dir, create_directory
  USE io_global, ONLY : ionode, ionode_id
  USE kinds, ONLY : DP
  USE mp, ONLY : mp_bcast
  USE mp_global, ONLY : mp_startup
  USE mp_world, ONLY : world_comm
  USE noncollin_module,   ONLY : noncolin, m_loc, angle1, angle2, nspin_lsda
  USE spin_orb,           ONLY : domag
  USE ions_base,          ONLY : nat, tau, ityp
  USE symm_base,          ONLY : nrot, nsym, s, t_rev, fft_fact, find_sym
  USE lsda_mod,           ONLY : nspin, isk, lsda, starting_magnetization
  USE extfield,           ONLY : gate

  IMPLICIT NONE

  character(len=6) :: codename = 'BGW2PW'

  integer :: real_or_complex
  logical :: wfng_flag
  character ( len = 256 ) :: wfng_file
  integer :: wfng_nband
  logical :: rhog_flag
  character ( len = 256 ) :: rhog_file
  character ( len = 256 ) :: outdir

  NAMELIST / input_bgw2pw / prefix, outdir, &
       real_or_complex, wfng_flag, wfng_file, wfng_nband, &
       rhog_flag, rhog_file

  integer :: ios, na
  character ( len = 256 ) :: input_file_name
  character ( len = 256 ) :: output_dir_name

  character (len=256), external :: trimcheck
  LOGICAL :: magnetic_sym

#if defined(__MPI)
  CALL mp_startup ( )
#endif

  CALL environment_start ( codename )

  prefix = 'prefix'
  CALL get_environment_variable ( 'ESPRESSO_TMPDIR', outdir )
  IF ( TRIM ( outdir ) == ' ' ) outdir = './'
  real_or_complex = 2
  wfng_flag = .FALSE.
  wfng_file = 'WFN'
  wfng_nband = 0
  rhog_flag = .FALSE.
  rhog_file = 'RHO'

  IF ( ionode ) THEN
     CALL input_from_file ( )
     READ ( 5, input_bgw2pw, iostat = ios )
     IF ( ios /= 0 ) CALL errore ( codename, 'input_bgw2pw', abs ( ios ) )
     IF ( real_or_complex /= 1 .AND. real_or_complex /= 2 ) &
          CALL errore ( codename, 'real_or_complex', 1 )
     IF ( wfng_nband .LT. 0 ) CALL errore ( codename, 'wfng_nband', 1 )
  ENDIF

  tmp_dir = trimcheck ( outdir )
  CALL mp_bcast ( tmp_dir, ionode_id, world_comm )
  CALL mp_bcast ( prefix, ionode_id, world_comm )
  CALL mp_bcast ( real_or_complex, ionode_id, world_comm )
  CALL mp_bcast ( wfng_flag, ionode_id, world_comm )
  CALL mp_bcast ( wfng_file, ionode_id, world_comm )
  CALL mp_bcast ( wfng_nband, ionode_id, world_comm )
  CALL mp_bcast ( rhog_flag, ionode_id, world_comm )
  CALL mp_bcast ( rhog_file, ionode_id, world_comm )

  CALL read_file ( )

  ! CALL openfil_pp ( )

  ! CALL open_buffer(iunwfc, 'wfc', nwordwfc, io_level, exst_mem, exst)
  ! !
  ! WRITE(stdout,*)
  ! IF ( npool > 1 .and. nspin_mag>1) CALL errore( 'open_grid', &
  !      'pools+spin not implemented, run this tool with only one pool', npool )
  ! !
  ! IF(gamma_only) CALL errore("open_grid", &
  !      "not implemented, and pointless, for gamma-only",1)
  ! !
  ! ! Store some variables related to exx to be put back before writing
  ! use_ace_back = use_ace
  ! ecutfock_back = ecutfock
  ! nq_back = (/ nq1, nq2, nq3 /)
  ! exx_status_back = .true.
  ! CALL dft_force_hybrid(exx_status_back)

  ! magnetic_sym = noncolin .AND. domag
  ! ALLOCATE(m_loc(3,nat))
  ! IF (noncolin.and.domag) THEN
  !    DO na = 1, nat
  !       m_loc(1,na) = starting_magnetization(ityp(na)) * &
  !            SIN( angle1(ityp(na)) ) * COS( angle2(ityp(na)) )
  !       m_loc(2,na) = starting_magnetization(ityp(na)) * &
  !            SIN( angle1(ityp(na)) ) * SIN( angle2(ityp(na)) )
  !       m_loc(3,na) = starting_magnetization(ityp(na)) * &
  !            COS( angle1(ityp(na)) )
  !    ENDDO
  ! ENDIF
  ! CALL find_sym ( nat, tau, ityp, magnetic_sym, m_loc, gate )

  ! nq1 = -1
  ! nq2 = -1
  ! nq3 = -1
  ! ecutfock = 4*ecutwfc
  ! use_ace = .false.

  ! CALL exx_grid_init()
  ! CALL exx_mp_init()
  ! !
  ! CALL exxinit(.false.)
  ! qnorm = 0._dp
  ! !
  ! CALL close_buffer(iunwfc,'keep')

  IF ( wfng_flag ) THEN
     input_file_name = TRIM ( tmp_dir ) // TRIM ( wfng_file )
     output_dir_name = TRIM ( tmp_dir ) // TRIM ( prefix ) // '.save'
     IF ( ionode ) WRITE ( 6, '(5x,"call write_evc")' )
     CALL start_clock ( 'write_evc' )
     CALL write_evc ( input_file_name, real_or_complex, wfng_nband, &
          output_dir_name )
     CALL stop_clock ( 'write_evc' )
     IF ( ionode ) WRITE ( 6, '(5x,"done write_evc",/)' )
  ENDIF

  IF ( rhog_flag ) THEN
    input_file_name = TRIM ( tmp_dir ) // TRIM ( rhog_file )
    output_dir_name = TRIM ( tmp_dir ) // TRIM ( prefix ) // '.save'
    IF ( ionode ) WRITE ( 6, '(5x,"call write_cd")' )
    CALL start_clock ( 'write_cd' )
    CALL write_cd ( input_file_name, real_or_complex, output_dir_name )
    CALL stop_clock ( 'write_cd' )
    IF ( ionode ) WRITE ( 6, '(5x,"done write_cd",/)' )
  ENDIF

  IF ( ionode ) WRITE ( 6, * )
  IF ( wfng_flag ) CALL print_clock ( 'write_evc' )
  IF ( rhog_flag ) CALL print_clock ( 'write_cd' )

  CALL environment_end ( codename )

  CALL stop_pp ( )

  ! this is needed because openfil is called above
  CALL close_files ( .false. )

  STOP

CONTAINS

  !-------------------------------------------------------------------------------

  SUBROUTINE write_evc ( input_file_name, real_or_complex, &
       wfng_nband, output_dir_name )

    USE cell_base, ONLY : omega, alat, tpiba, tpiba2, at, bg
    USE constants, ONLY : eps6
    USE fft_base, ONLY : dfftp
    USE gvect, ONLY : ngm, ngm_g, ig_l2g, mill, g
    USE io_global, ONLY : ionode, ionode_id
    USE io_files,   ONLY : prefix, tmp_dir, nwordwfc, iunwfc, diropn
    USE ions_base, ONLY : nat
    USE iotk_module, ONLY : iotk_attlenx, iotk_free_unit, iotk_open_write, &
         iotk_write_begin, iotk_write_attr, iotk_write_empty, iotk_write_dat, &
         iotk_write_end, iotk_close_write, iotk_index
    USE kinds, ONLY : DP
    USE klist, ONLY : xk, wk, nks, nkstot, ngk, igk_k
    USE lsda_mod, ONLY : nspin
    USE mp, ONLY : mp_bcast, mp_sum, mp_max, mp_barrier
    USE mp_world, ONLY : world_comm, nproc
    USE mp_pools, ONLY : kunit, npool, my_pool_id, intra_pool_comm
    USE symm_base, ONLY : s, nsym
#if defined (__OLDXML)
    USE qexml_module, ONLY : qexml_kpoint_dirname, qexml_wfc_filename
#endif
#if defined(__MPI)
    USE parallel_include, ONLY : MPI_INTEGER, MPI_DOUBLE_COMPLEX
#endif
    USE wvfct, ONLY : npwx, nbnd, et, wg
    USE noncollin_module , ONLY : noncolin , npol
    USE buffers,            ONLY : save_buffer, open_buffer, close_buffer
    USE wavefunctions, ONLY : evc, psic, psic_nc
    USE scf,                ONLY : rho
    USE io_rho_xml,         ONLY : write_scf

    IMPLICIT NONE

    character ( len = 256 ), intent ( in ) :: input_file_name
    integer, intent ( in ) :: real_or_complex
    integer, intent ( in ) :: wfng_nband
    character ( len = 256 ), intent ( in ) :: output_dir_name

    logical :: f1, f2
    integer :: ierr, i, j, iu, ik, is, ib, ig, jg, fg, ir, &
         na, nk, ns, nb, nbgw, ng, npwx_g, ntran, cell_symmetry, &
         iks, ike, npw, npw_g, ngkdist_l, ngkdist_g, &
         igk_l2g, irecord, nrecord, ng_irecord, nr ( 3 )
    integer :: global_kpoint_index
    real ( DP ) :: ecutrho, ecutwfn, celvol, recvol, al, bl, xdel, &
         a ( 3, 3 ), b ( 3, 3 ), adot ( 3, 3 ), bdot ( 3, 3 )
    character :: sdate*32, stime*32, stitle*32
    character ( len = 256 ) :: filename
    character ( iotk_attlenx ) :: attr

    integer, allocatable :: ngk_g ( : )
    integer, allocatable :: gvec ( :, : )
    integer, allocatable :: igk_buf ( : )
    integer, allocatable :: igk_dist ( :, : )
    integer, allocatable :: gk_buf ( :, : )
    integer, allocatable :: gk_dist ( :, : )
    real ( DP ), allocatable :: k ( :, : )
    real ( DP ), allocatable :: en ( :, :, : )
    real ( DP ), allocatable :: oc ( :, :, : )
    real ( DP ), allocatable :: wfngr ( :, : )
    complex ( DP ), allocatable :: wfngc ( :, : )
    complex ( DP ), allocatable :: wfng_buf ( :, : )
    complex ( DP ), allocatable :: wfng_dist ( :, :, :, : )
    LOGICAL :: exst, opnd, exst_mem, magnetic_sym

    integer :: ig_evc, ig_g

    CALL check_inversion ( real_or_complex, nsym, s, nspin, .true., .true. )

    IF ( ionode ) CALL iotk_free_unit ( iu )

    IF ( ionode ) THEN
       OPEN ( unit = iu, file = TRIM ( input_file_name ), &
            form = 'unformatted', status = 'old' )
       READ ( iu ) stitle, sdate, stime
    ENDIF

    CALL mp_bcast ( stitle, ionode_id, world_comm )
    f1 = real_or_complex == 1 .AND. stitle(1:8) == 'WFN-Real'
    f2 = real_or_complex == 2 .AND. stitle(1:11) == 'WFN-Complex'
    IF ( ( .NOT. f1 ) .AND. ( .NOT. f2 ) ) &
         CALL errore ( 'write_evc', 'file header', 1 )

    IF ( ionode ) THEN
       READ ( iu ) ns, ng, ntran, cell_symmetry, na, ecutrho, nk, nb, npwx_g, ecutwfn
       READ ( iu ) ( nr ( ir ), ir = 1, 3 )
       READ ( iu ) celvol, al, ( ( a ( j, i ), j = 1, 3 ), i = 1, 3 ), &
            ( ( adot ( j, i ), j = 1, 3 ), i = 1, 3 )
       READ ( iu ) recvol, bl, ( ( b ( j, i ), j = 1, 3 ), i = 1, 3 ), &
            ( ( bdot ( j, i ), j = 1, 3 ), i = 1, 3 )

       if (ns .eq. 2) then
          CALL errore ( 'write_evc', 'do not support ns=2 for now', 1 )
       endif
    ENDIF

    CALL mp_bcast ( ns, ionode_id, world_comm )
    CALL mp_bcast ( ng, ionode_id, world_comm )
    CALL mp_bcast ( ntran, ionode_id, world_comm )
    CALL mp_bcast ( cell_symmetry, ionode_id, world_comm )
    CALL mp_bcast ( na, ionode_id, world_comm )
    CALL mp_bcast ( ecutrho, ionode_id, world_comm )
    CALL mp_bcast ( nk, ionode_id, world_comm )
    CALL mp_bcast ( nb, ionode_id, world_comm )
    CALL mp_bcast ( npwx_g, ionode_id, world_comm )
    CALL mp_bcast ( ecutwfn, ionode_id, world_comm )
    CALL mp_bcast ( nr, ionode_id, world_comm )
    CALL mp_bcast ( celvol, ionode_id, world_comm )
    CALL mp_bcast ( al, ionode_id, world_comm )
    CALL mp_bcast ( a, ionode_id, world_comm )
    CALL mp_bcast ( adot, ionode_id, world_comm )
    CALL mp_bcast ( recvol, ionode_id, world_comm )
    CALL mp_bcast ( bl, ionode_id, world_comm )
    CALL mp_bcast ( b, ionode_id, world_comm )
    CALL mp_bcast ( bdot, ionode_id, world_comm )

    IF ( ns .NE. nspin ) CALL errore ( 'write_evc', 'ns', 1 )
    IF ( ng .NE. ngm_g ) CALL errore ( 'write_evc', 'ng', 1 )
    IF ( na .NE. nat ) CALL errore ( 'write_evc', 'na', 1 )
    IF ( nk .NE. nkstot / nspin ) CALL errore ( 'write_evc', 'nk', 1 )
    IF ( nr ( 1 ) .NE. dfftp%nr1 .OR. nr ( 2 ) .NE. dfftp%nr2 .OR. nr ( 3 ) .NE. dfftp%nr3 ) &
         CALL errore ( 'write_evc', 'nr', 1 )
    IF ( abs ( celvol - omega ) .GT. eps6 ) &
         CALL errore ( 'write_evc', 'unit cell volume', 1 )
    xdel = 0.0D0
    DO i = 1, 3
       DO j = 1, 3
          xdel = xdel + abs ( al * a ( j, i ) - alat * at ( j, i ) )
       ENDDO
    ENDDO
    IF ( xdel .GT. eps6 ) &
         CALL errore ( 'write_evc', 'direct lattice vectors', 1 )
    xdel = 0.0D0
    DO i = 1, 3
       DO j = 1, 3
          xdel = xdel + abs ( bl * b ( j, i ) - tpiba * bg ( j, i ) )
       ENDDO
    ENDDO
    IF ( xdel .GT. eps6 ) &
         CALL errore ( 'write_evc', 'reciprocal lattice vectors', 1 )

    nbgw = nb
    IF ( wfng_nband .GT. 0 .AND. wfng_nband .LT. nb ) nb = wfng_nband

    IF ( MOD ( npwx_g, nproc ) .EQ. 0 ) THEN
       ngkdist_l = npwx_g / nproc
    ELSE
       ngkdist_l = npwx_g / nproc + 1
    ENDIF
    ngkdist_g = ngkdist_l * nproc

    ! write(*,*) "ngkdist_l = ", ngkdist_l, " npwx = ", npwx, " nk = ", nk, " ngk = ", ngk

    ALLOCATE ( ngk_g ( nk ) )
    ALLOCATE ( k ( 3, nk ) )
    ALLOCATE ( en ( nb, nk, ns ) )
    ALLOCATE ( oc ( nb, nk, ns ) )
    ALLOCATE ( gvec ( 3, ng ) )
    ALLOCATE ( igk_buf ( ngkdist_g ) )
    ALLOCATE ( igk_dist ( ngkdist_l, nk ) )
    ALLOCATE ( gk_buf ( 3, ngkdist_g ) )
    ALLOCATE ( gk_dist ( 3, ngkdist_l ) )
    IF ( real_or_complex .EQ. 1 ) THEN
       ALLOCATE ( wfngr ( npwx_g, ns ) )
    ELSE
       ALLOCATE ( wfngc ( npwx_g, ns ) )
    ENDIF
    ALLOCATE ( wfng_buf ( ngkdist_g, ns ) )
    ALLOCATE ( wfng_dist ( ngkdist_l, nb, ns, nk ) )

    IF ( ionode ) THEN
       READ ( iu )
       READ ( iu )
       READ ( iu )
       READ ( iu ) ( ngk_g ( ik ), ik = 1, nk )
       READ ( iu )
       READ ( iu ) ( ( k ( ir, ik ), ir = 1, 3 ), ik = 1, nk )
       READ ( iu )
       READ ( iu )
       READ ( iu ) ( ( ( en ( ib, ik, is ), ib = 1, nb ), ik = 1, nk ), is = 1, ns )
       READ ( iu ) ( ( ( oc ( ib, ik, is ), ib = 1, nb ), ik = 1, nk ), is = 1, ns )
       READ ( iu ) nrecord
       ig = 1
       !> [Important]
       DO irecord = 1, nrecord
          READ ( iu ) ng_irecord
          READ ( iu ) ( ( gvec ( ir, jg ), ir = 1, 3 ), jg = ig, ig + ng_irecord - 1 )
          ig = ig + ng_irecord
       ENDDO
    ENDIF

    IF ( ionode ) THEN
       CALL cryst_to_cart ( nk, k, bg, 1 )
       DO is = 1, ns
          !> This is possible since we only one k pool
          DO ik = 1, nk
             DO ib = 1, nb
                !> en in WFN in Ryd, et in WFN in Hartree
                ! en ( ib, ik, is ) = en ( ib, ik, is ) / 2.0D0
                et ( ib, ik+(is-1)*nk ) = en ( ib, ik, is )
                if (ns == 1) then
                   ! wg ( ib, ik+(is-1)*nk ) = oc ( ib, ik, is ) * 2
                   wg ( ib, ik+(is-1)*nk ) = oc ( ib, ik, is ) * wk(ik)
                else
                   !> [Need TESTING]
                   ! wg ( ib, ik+(is-1)*nk ) = oc ( ib, ik, is )
                   wg ( ib, ik+(is-1)*nk ) = oc ( ib, ik, is ) * wk(ik) / 2.0
                endif
             ENDDO
          ENDDO
       ENDDO
    ENDIF

    CALL mp_bcast ( ngk_g, ionode_id, world_comm )
    CALL mp_bcast ( k, ionode_id, world_comm )
    !> [Important]
    ! CALL mp_bcast ( en, ionode_id, world_comm )
    CALL mp_bcast ( et, ionode_id, world_comm )
    !> [Important]
    ! CALL mp_bcast ( oc, ionode_id, world_comm )
    CALL mp_bcast ( wg, ionode_id, world_comm )
    CALL mp_bcast ( gvec, ionode_id, world_comm )

    fg = 0
    DO ig = 1, ngm
       IF ( ( gvec ( 1, ig_l2g ( ig ) ) .NE. mill ( 1, ig ) ) .OR. &
            ( gvec ( 2, ig_l2g ( ig ) ) .NE. mill ( 2, ig ) ) .OR. &
            ( gvec ( 3, ig_l2g ( ig ) ) .NE. mill ( 3, ig ) ) ) &
            fg = fg + 1
    ENDDO
    CALL mp_sum ( fg, intra_pool_comm )
    IF ( fg .GT. 0 ) THEN
       IF ( ionode ) WRITE ( 6, 101 )
       gvec ( :, : ) = 0
       DO ig = 1, ngm
          gvec ( 1, ig_l2g ( ig ) ) = mill ( 1, ig )
          gvec ( 2, ig_l2g ( ig ) ) = mill ( 2, ig )
          gvec ( 3, ig_l2g ( ig ) ) = mill ( 3, ig )
       ENDDO
       CALL mp_sum ( gvec, intra_pool_comm )
    ENDIF

    DO ik = 1, nk

       IF ( ionode ) THEN
          READ ( iu ) nrecord
          ig = 1
          DO irecord = 1, nrecord
             READ ( iu ) ng_irecord
             READ ( iu ) ( ( gk_buf ( ir, jg ), ir = 1, 3 ), jg = ig, ig + ng_irecord - 1 )
             ig = ig + ng_irecord
          ENDDO
          DO ig = ngk_g ( ik ) + 1, ngkdist_g
             DO ir = 1, 3
                gk_buf ( ir, ig ) = 0
             ENDDO
          ENDDO
       ENDIF
#if defined(__MPI)
       CALL mp_barrier ( world_comm )
       CALL MPI_Scatter ( gk_buf, 3 * ngkdist_l, MPI_INTEGER, &
            gk_dist, 3 * ngkdist_l, MPI_INTEGER, &
            ionode_id, world_comm, ierr )
       IF ( ierr .GT. 0 ) CALL errore ( 'write_evc', 'mpi_scatter', ierr )
#else
       DO ig = 1, ngkdist_g
          DO ir = 1, 3
             gk_dist ( ir, ig ) = gk_buf ( ir, ig )
          ENDDO
       ENDDO
#endif
       DO ig = 1, ngkdist_l
          DO jg = 1, ng
             IF ( gk_dist ( 1, ig ) .EQ. gvec ( 1, jg ) .AND. &
                  gk_dist ( 2, ig ) .EQ. gvec ( 2, jg ) .AND. &
                  gk_dist ( 3, ig ) .EQ. gvec ( 3, jg ) ) THEN
                igk_dist ( ig, ik ) = jg
                EXIT
             ENDIF
          ENDDO
       ENDDO

       DO ib = 1, nb
          IF ( ionode ) THEN
             !> nrecord = 1
             READ ( iu ) nrecord
             ig = 1
             DO irecord = 1, nrecord
                !> ng_irecord = ngk_g(ik)
                READ ( iu ) ng_irecord
                IF ( real_or_complex .EQ. 1 ) THEN
                   READ ( iu ) ( ( wfngr ( jg, is ), jg = ig, ig + ng_irecord - 1 ), is = 1, ns )
                ELSE
                   READ ( iu ) ( ( wfngc ( jg, is ), jg = ig, ig + ng_irecord - 1 ), is = 1, ns )
                ENDIF
                ig = ig + ng_irecord
             ENDDO
             DO is = 1, ns
                IF ( real_or_complex .EQ. 1 ) THEN
                   DO ig = 1, ngk_g ( ik )
                      wfng_buf ( ig, is ) = CMPLX ( wfngr ( ig, is ), 0.0D0, KIND=dp )
                   ENDDO
                ELSE
                   DO ig = 1, ngk_g ( ik )
                      wfng_buf ( ig, is ) = wfngc ( ig, is )
                   ENDDO
                ENDIF
                DO ig = ngk_g ( ik ) + 1, ngkdist_g
                   wfng_buf ( ig, is ) = ( 0.0D0, 0.0D0 )
                ENDDO
             ENDDO
          ENDIF
#if defined(__MPI)
          DO is = 1, ns
             CALL mp_barrier ( world_comm )
             CALL MPI_Scatter ( wfng_buf ( :, is ), ngkdist_l, MPI_DOUBLE_COMPLEX, &
                  wfng_dist ( :, ib, is, ik ), ngkdist_l, MPI_DOUBLE_COMPLEX, &
                  ionode_id, world_comm, ierr )
             IF ( ierr .GT. 0 ) CALL errore ( 'write_evc', 'mpi_scatter', ierr )
          ENDDO
#else
          DO is = 1, ns
             DO ig = 1, ngkdist_g
                wfng_dist ( ig, ib, is, ik ) = wfng_buf ( ig, is )
             ENDDO
          ENDDO
#endif
       ENDDO

       !> [??????]
       IF ( ik .LT. nk ) THEN
          DO ib = nb + 1, nbgw
             IF ( ionode ) THEN
                READ ( iu ) nrecord
                DO irecord = 1, nrecord
                   READ ( iu )
                   READ ( iu )
                ENDDO
             ENDIF
          ENDDO
       ENDIF

    ENDDO

    IF ( ionode ) THEN
       CLOSE ( unit = iu, status = 'keep' )
    ENDIF

    DEALLOCATE ( gk_buf )
    DEALLOCATE ( gk_dist )
    IF ( real_or_complex .EQ. 1 ) THEN
       DEALLOCATE ( wfngr )
    ELSE
       DEALLOCATE ( wfngc )
    ENDIF

    CALL mp_bcast ( ngk_g, ionode_id, world_comm )

    iks =  global_kpoint_index (nkstot, 1)
    ike = iks + nks -1

    npw_g = 0
    DO ik = 1, nks
       npw = ngk ( ik )
       DO ig = 1, npw
          igk_l2g = ig_l2g ( igk_k (ig, ik) )
          IF ( igk_l2g .GT. npw_g ) npw_g = igk_l2g
       ENDDO
    ENDDO
    CALL mp_max ( npw_g, world_comm )

    !     CALL create_directory ( output_dir_name )
    ! #if defined (__OLDXML)
    !     DO ik = 1, nk
    !        CALL create_directory (qexml_kpoint_dirname( output_dir_name, ik ) )
    !     ENDDO
    ! #else
    !     CALL errore('bgw2pw','XSD implementation pending',1)
    ! #endif

    !     filename = TRIM ( output_dir_name ) // '/gvectors.dat'

    !     IF ( ionode ) THEN
    !        CALL iotk_open_write ( iu, FILE = TRIM ( filename ), SKIP_ROOT = .TRUE., BINARY = .TRUE. )
    !        CALL iotk_write_begin ( iu, "G-VECTORS" )
    !        CALL iotk_write_attr ( attr, "nr1s", nr ( 1 ), FIRST = .TRUE. )
    !        CALL iotk_write_attr ( attr, "nr2s", nr ( 2 ) )
    !        CALL iotk_write_attr ( attr, "nr3s", nr ( 3 ) )
    !        CALL iotk_write_attr ( attr, "gvect_number", ng )
    !        CALL iotk_write_attr ( attr, "gamma_only", .FALSE. )
    !        CALL iotk_write_attr ( attr, "units", "crystal" )
    !        CALL iotk_write_empty ( iu, "INFO", ATTR = attr )
    !        CALL iotk_write_dat ( iu, "g", gvec ( 1 : 3, 1 : ng ), COLUMNS = 3 )
    !        CALL iotk_write_end ( iu, "G-VECTORS" )
    !        CALL iotk_close_write ( iu )
    !     ENDIF

    prefix = TRIM(prefix)//"_newwfn"
    nwordwfc = nbnd * npwx * npol
    CALL open_buffer(iunwfc, 'wfc', nwordwfc, +1, exst_mem, exst)

    ! Write everything again with the new prefix
    ! CALL write_scf(rho, nspin)

    ! write(*,*) "nk = ", nk

    DO ik = 1, nk

       ! #if defined (__OLDXML)
       !        filename = TRIM ( qexml_wfc_filename ( output_dir_name, 'gkvectors', ik ) )
       ! #endif
       !        IF ( ionode ) THEN
       !           CALL iotk_open_write ( iu, FILE = TRIM ( filename ), ROOT="GK-VECTORS", BINARY = .TRUE. )
       !           CALL iotk_write_dat ( iu, "NUMBER_OF_GK-VECTORS", ngk_g ( ik ) )
       !           CALL iotk_write_dat ( iu, "MAX_NUMBER_OF_GK-VECTORS", npwx_g )
       !           CALL iotk_write_dat ( iu, "GAMMA_ONLY", .FALSE. )
       !           CALL iotk_write_attr ( attr, "UNITS", "2 pi / a", FIRST = .TRUE. )
       !           CALL iotk_write_dat ( iu, "K-POINT_COORDS", k ( :, ik ), ATTR = attr )
       !        ENDIF
#if defined(__MPI)
       CALL mp_barrier ( world_comm )
       ! CALL MPI_Gather ( igk_dist ( :, ik ) , ngkdist_l, MPI_INTEGER, &
       !      igk_buf, ngkdist_l, MPI_INTEGER, &
       !      ionode_id, world_comm, ierr )
       CALL MPI_ALLGather ( igk_dist ( :, ik ) , ngkdist_l, MPI_INTEGER, &
            igk_buf, ngkdist_l, MPI_INTEGER, world_comm, ierr )
       IF ( ierr .GT. 0 ) CALL errore ( 'write_evc', 'mpi_gather', ierr )
#else
       DO ig = 1, ngkdist_g
          igk_buf ( ig ) = igk_dist ( ig, ik )
       ENDDO
#endif
       ! IF ( ionode ) THEN
       !    CALL iotk_write_dat ( iu, "INDEX", igk_buf ( 1 : ngk_g ( ik ) ) )
       !    CALL iotk_write_dat ( iu, "GRID", gvec ( 1 : 3, igk_buf ( 1 : ngk_g ( ik ) ) ), COLUMNS = 3 )
       !    CALL iotk_close_write ( iu )
       ! ENDIF

       DO is = 1, ns
          ! #if defined (__OLDXML)
          !           IF ( ns .GT. 1 ) THEN
          !              filename = TRIM ( qexml_wfc_filename ( output_dir_name, 'eigenval', ik, is, EXTENSION = 'xml' ) )
          !           ELSE
          !              filename = TRIM ( qexml_wfc_filename ( output_dir_name, 'eigenval', ik, EXTENSION = 'xml' ) )
          !           ENDIF
          ! #endif
          !           IF ( ionode ) THEN
          !              CALL iotk_open_write ( iu, FILE = TRIM ( filename ), BINARY = .FALSE. )
          !              CALL iotk_write_attr ( attr, "nbnd", nb, FIRST = .TRUE. )
          !              CALL iotk_write_attr ( attr, "ik", ik )
          !              IF ( ns .GT. 1 ) CALL iotk_write_attr ( attr, "ispin", is )
          !              CALL iotk_write_empty ( iu, "INFO", ATTR = attr )
          !              CALL iotk_write_attr ( attr, "UNITS", "Hartree", FIRST = .TRUE. )
          !              CALL iotk_write_empty ( iu, "UNITS_FOR_ENERGIES", ATTR = attr )
          !              CALL iotk_write_dat ( iu, "EIGENVALUES", en ( :, ik, is ) )
          !              CALL iotk_write_dat ( iu, "OCCUPATIONS", oc ( :, ik, is ) )
          !              CALL iotk_close_write ( iu )
          !           ENDIF
          ! #if defined (__OLDXML)
          !           IF ( ns .GT. 1 ) THEN
          !              filename = TRIM ( qexml_wfc_filename ( output_dir_name, 'evc', ik, is ) )
          !           ELSE
          !              filename = TRIM ( qexml_wfc_filename ( output_dir_name, 'evc', ik ) )
          !           ENDIF
          ! #endif
          !           IF ( ionode ) THEN
          !              CALL iotk_open_write ( iu, FILE = TRIM ( filename ), ROOT = "WFC", BINARY = .TRUE. )
          !              CALL iotk_write_attr ( attr, "ngw", npw_g, FIRST = .TRUE. )
          !              CALL iotk_write_attr ( attr, "igwx", ngk_g ( ik ) )
          !              CALL iotk_write_attr ( attr, "gamma_only", .FALSE. )
          !              CALL iotk_write_attr ( attr, "nbnd", nb )
          !              CALL iotk_write_attr ( attr, "ik", ik )
          !              CALL iotk_write_attr ( attr, "nk", nk )
          !              CALL iotk_write_attr ( attr, "ispin", is )
          !              CALL iotk_write_attr ( attr, "nspin", ns )
          !              CALL iotk_write_attr ( attr, "scale_factor", 1.0D0 )
          !              CALL iotk_write_empty ( iu, "INFO", attr )
          !           ENDIF

          evc = (0.0D0, 0.0D0)

          DO ib = 1, nb
#if defined(__MPI)
             CALL mp_barrier ( world_comm )
             ! CALL MPI_Gather ( wfng_dist ( :, ib, is, ik ), ngkdist_l, MPI_DOUBLE_COMPLEX, &
             !      wfng_buf ( :, is ), ngkdist_l, MPI_DOUBLE_COMPLEX, &
             !      ionode_id, world_comm, ierr )
             !> All proc now has wfng_buf
             CALL MPI_ALLGather ( wfng_dist ( :, ib, is, ik ), ngkdist_l, MPI_DOUBLE_COMPLEX, &
                  wfng_buf ( :, is ), ngkdist_l, MPI_DOUBLE_COMPLEX, world_comm, ierr )
             IF ( ierr .GT. 0 ) CALL errore ( 'write_evc', 'mpi_gather', ierr )
#else
             DO ig = 1, ngkdist_g
                wfng_buf ( ig, is ) = wfng_dist ( ig, ib, is, ik )
             ENDDO
#endif

             ! if (ib .eq. 1) then
             !    if (ionode) then
             !       write(*,*) "wfng_buf(:,ib=1)"
             !       do ig_g = 1, ngkdist_g
             !          write(*,'(3I5, 2ES20.10)') gvec(:,igk_buf(ig_g)), wfng_buf(ig_g,1)
             !       enddo
             !    endif
             ! endif

             ! IF ( ionode ) CALL iotk_write_dat ( iu, "evc" // iotk_index ( ib ), wfng_buf ( 1 : ngk_g ( ik ), is ) )

             !> [ns = 2?]
             !> [SOC?]
             !> ALLOCATE ( wfng_buf ( ngkdist_g, ns ) )
             DO ig_evc = 1, ngk(ik)
                if (ig_l2g(igk_k(ig_evc,ik)) <= 0) then
                   continue
                endif
                loop_ig: DO ig_g = 1, ngkdist_g
                   !> igk_l2g(ig_evc, ik) ==> index in gvec(1:3,1:ngm_g)
                   if (igk_buf(ig_g) <= 0) then
                      continue
                   endif
                   if (ig_l2g(igk_k(ig_evc,ik)) .eq. igk_buf(ig_g)) then
                      evc(ig_evc, ib) = wfng_buf(ig_g, is)
                      exit loop_ig
                   endif
                ENDDO loop_ig
             ENDDO
          ENDDO

          ! if (ionode) then
          !    write(*,*) "evc recovered: ib = 1"
          !    do ig_evc = 1, ngk(ik)
          !       write(*,'(3I5, 2ES20.10, 2I5,A,I5, 2ES20.10)') gvec(:,ig_l2g(igk_k(ig_evc,ik))), evc(ig_evc,1), igk_k(ig_evc,ik), ig_l2g(igk_k(ig_evc,ik)), " igk_buf(1) = ", igk_buf(1), wfng_buf(1, is)
          !    enddo
          ! endif

          CALL save_buffer( evc, nwordwfc, iunwfc, ik + (is-1)*nk )

          ! IF ( ionode ) CALL iotk_close_write ( iu )
       ENDDO ! ib
    ENDDO ! is

    !> PUNCH
    CALL punch('all')

    DEALLOCATE ( ngk_g )
    DEALLOCATE ( k )
    DEALLOCATE ( en )
    DEALLOCATE ( oc )
    DEALLOCATE ( gvec )
    DEALLOCATE ( igk_buf )
    DEALLOCATE ( igk_dist )
    DEALLOCATE ( wfng_buf )
    DEALLOCATE ( wfng_dist )

    CALL mp_barrier ( world_comm )

    RETURN

101 FORMAT ( 5X, "WARNING: reordering G-vectors" )

  END SUBROUTINE write_evc

  !-------------------------------------------------------------------------------

  SUBROUTINE write_cd ( input_file_name, real_or_complex, output_dir_name )

    USE cell_base, ONLY : omega, alat, tpiba, at, bg
    USE constants, ONLY : eps6
    USE fft_base, ONLY : dfftp
    USE fft_interfaces, ONLY : invfft
    USE gvect, ONLY : ngm, ngm_g, ig_l2g, mill
    USE io_global, ONLY : ionode, ionode_id
    USE ions_base, ONLY : nat
    ! USE xml_io_base, ONLY : write_rho    
    ! USE iotk_module, ONLY : iotk_attlenx, iotk_free_unit, iotk_open_write, &
    !   iotk_write_begin, iotk_write_attr, iotk_write_empty, iotk_write_dat, &
    !   iotk_write_end, iotk_close_write
    USE io_rho_xml,         ONLY : write_scf    
    USE kinds, ONLY : DP
    USE lsda_mod, ONLY : nspin
    USE mp, ONLY : mp_bcast, mp_sum
    USE mp_pools, ONLY : intra_pool_comm
    USE mp_world, ONLY : world_comm
    USE scf, ONLY : rho
    USE symm_base, ONLY : s, nsym
    USE wavefunctions, ONLY : psic

    IMPLICIT NONE

    character ( len = 256 ), intent ( in ) :: input_file_name
    integer, intent ( in ) :: real_or_complex
    character ( len = 256 ), intent ( in ) :: output_dir_name

    logical :: f1, f2
    integer :: i, j, iu, is, ig, jg, fg, ir, ns, ng, &
      ntran, cell_symmetry, na, irecord, nrecord, ng_irecord, nr ( 3 )
    real ( DP ) :: ecutrho, celvol, recvol, al, bl, xdel, &
      a ( 3, 3 ), b ( 3, 3 ), adot ( 3, 3 ), bdot ( 3, 3 )
    character :: sdate*32, stime*32, stitle*32
    character ( len = 256 ) :: filename
    character ( iotk_attlenx ) :: attr

    integer, allocatable :: gvec ( :, : )
    real ( DP ), allocatable :: rhogr ( :, : )
    complex ( DP ), allocatable :: rhogc ( :, : )
    complex ( DP ), allocatable :: rhog ( :, : )
    complex ( DP ), allocatable :: rhog_unsrt ( :, : )

    CALL check_inversion ( real_or_complex, nsym, s, nspin, .true., .true. )

    ! IF ( ionode ) CALL iotk_free_unit ( iu )

    IF ( ionode ) THEN
      OPEN ( unit = iu, file = TRIM ( input_file_name ), &
        form = 'unformatted', status = 'old' )
      READ ( iu ) stitle, sdate, stime
    ENDIF

    CALL mp_bcast ( stitle, ionode_id, world_comm )
    f1 = real_or_complex == 1 .AND. stitle(1:8) == 'RHO-Real'
    f2 = real_or_complex == 2 .AND. stitle(1:11) == 'RHO-Complex'
    IF ( ( .NOT. f1 ) .AND. ( .NOT. f2 ) ) &
      CALL errore ( 'write_cd', 'file header', 1 )

    IF ( ionode ) THEN
      READ ( iu ) ns, ng, ntran, cell_symmetry, na, ecutrho
      READ ( iu ) ( nr ( ir ), ir = 1, 3 )
      READ ( iu ) celvol, al, ( ( a ( j, i ), j = 1, 3 ), i = 1, 3 ), &
        ( ( adot ( j, i ), j = 1, 3 ), i = 1, 3 )
      READ ( iu ) recvol, bl, ( ( b ( j, i ), j = 1, 3 ), i = 1, 3 ), &
        ( ( bdot ( j, i ), j = 1, 3 ), i = 1, 3 )
    ENDIF

    CALL mp_bcast ( ns, ionode_id, world_comm )
    CALL mp_bcast ( ng, ionode_id, world_comm )
    CALL mp_bcast ( ntran, ionode_id, world_comm )
    CALL mp_bcast ( cell_symmetry, ionode_id, world_comm )
    CALL mp_bcast ( na, ionode_id, world_comm )
    CALL mp_bcast ( ecutrho, ionode_id, world_comm )
    CALL mp_bcast ( nr, ionode_id, world_comm )
    CALL mp_bcast ( celvol, ionode_id, world_comm )
    CALL mp_bcast ( al, ionode_id, world_comm )
    CALL mp_bcast ( a, ionode_id, world_comm )
    CALL mp_bcast ( adot, ionode_id, world_comm )
    CALL mp_bcast ( recvol, ionode_id, world_comm )
    CALL mp_bcast ( bl, ionode_id, world_comm )
    CALL mp_bcast ( b, ionode_id, world_comm )
    CALL mp_bcast ( bdot, ionode_id, world_comm )

    IF ( ns .NE. nspin ) CALL errore ( 'write_cd', 'ns', 1 )
    IF ( ng .NE. ngm_g ) CALL errore ( 'write_cd', 'ng', 1 )
    IF ( na .NE. nat ) CALL errore ( 'write_cd', 'na', 1 )
    IF ( nr ( 1 ) .NE. dfftp%nr1 .OR. nr ( 2 ) .NE. dfftp%nr2 .OR. nr ( 3 ) .NE. dfftp%nr3 ) &
      CALL errore ( 'write_cd', 'nr', 1 )
    IF ( abs ( celvol - omega ) .GT. eps6 ) &
      CALL errore ( 'write_cd', 'unit cell volume', 1 )
    xdel = 0.0D0
    DO i = 1, 3
      DO j = 1, 3
        xdel = xdel + abs ( al * a ( j, i ) - alat * at ( j, i ) )
      ENDDO
    ENDDO
    IF ( xdel .GT. eps6 ) &
      CALL errore ( 'write_cd', 'direct lattice vectors', 1 )
    xdel = 0.0D0
    DO i = 1, 3
      DO j = 1, 3
        xdel = xdel + abs ( bl * b ( j, i ) - tpiba * bg ( j, i ) )
      ENDDO
    ENDDO
    IF ( xdel .GT. eps6 ) &
      CALL errore ( 'write_cd', 'reciprocal lattice vectors', 1 )

    ALLOCATE ( gvec ( 3, ng ) )
    IF ( real_or_complex .EQ. 1 ) THEN
      ALLOCATE ( rhogr ( ng, ns ) )
    ELSE
      ALLOCATE ( rhogc ( ng, ns ) )
    ENDIF
    ALLOCATE ( rhog ( ng, ns ) )

    IF ( ionode ) THEN
      READ ( iu )
      READ ( iu )
      READ ( iu )
      READ ( iu ) nrecord
      ig = 1
      DO irecord = 1, nrecord
        READ ( iu ) ng_irecord
        READ ( iu ) ( ( gvec ( ir, jg ), ir = 1, 3 ), jg = ig, ig + ng_irecord - 1 )
        ig = ig + ng_irecord
      ENDDO
      READ ( iu ) nrecord
      ig = 1
      DO irecord = 1, nrecord
        READ ( iu ) ng_irecord
        IF ( real_or_complex .EQ. 1 ) THEN
          READ ( iu ) ( ( rhogr ( jg, is ), jg = ig, ig + ng_irecord - 1 ), is = 1, ns )
        ELSE
          READ ( iu ) ( ( rhogc ( jg, is ), jg = ig, ig + ng_irecord - 1 ), is = 1, ns )
        ENDIF
        ig = ig + ng_irecord
      ENDDO
      DO is = 1, ns
        IF ( real_or_complex .EQ. 1 ) THEN
          DO ig = 1, ng
            rhog ( ig, is ) = CMPLX ( rhogr ( ig, is ), 0.0D0, KIND=dp )
          ENDDO
        ELSE
          DO ig = 1, ng
            rhog ( ig, is ) = rhogc ( ig, is )
          ENDDO
        ENDIF
      ENDDO
      CLOSE ( unit = iu, status = 'keep' )
    ENDIF

    IF ( real_or_complex .EQ. 1 ) THEN
      DEALLOCATE ( rhogr )
    ELSE
      DEALLOCATE ( rhogc )
    ENDIF

    IF ( ionode ) THEN
      DO is = 1, ns
        DO ig = 1, ng
          rhog ( ig, is ) = rhog ( ig, is ) / CMPLX ( omega, 0.0D0, KIND=dp )
        ENDDO
      ENDDO
    ENDIF

    CALL mp_bcast ( gvec, ionode_id, world_comm )
    CALL mp_bcast ( rhog, ionode_id, world_comm )

    fg = 0
    DO ig = 1, ngm
      IF ( ( gvec ( 1, ig_l2g ( ig ) ) .NE. mill ( 1, ig ) ) .OR. &
           ( gvec ( 2, ig_l2g ( ig ) ) .NE. mill ( 2, ig ) ) .OR. &
           ( gvec ( 3, ig_l2g ( ig ) ) .NE. mill ( 3, ig ) ) ) &
        fg = fg + 1
    ENDDO
    CALL mp_sum ( fg, intra_pool_comm )
    IF ( fg .GT. 0 ) THEN
      IF ( ionode ) WRITE ( 6, 101 )
      ALLOCATE ( rhog_unsrt ( ng, ns ) )
      rhog_unsrt ( :, : ) = rhog ( :, : )
      rhog ( :, : ) = ( 0.0D0, 0.0D0 )
      DO ig = 1, ng
        DO jg = 1, ngm
          IF ( ( mill ( 1, jg ) .EQ. gvec ( 1, ig ) ) .AND. &
               ( mill ( 2, jg ) .EQ. gvec ( 2, ig ) ) .AND. &
               ( mill ( 3, jg ) .EQ. gvec ( 3, ig ) ) ) THEN
            DO is = 1, ns
              rhog ( ig_l2g ( jg ), is ) = rhog_unsrt ( ig, is )
            ENDDO
          ENDIF
        ENDDO
      ENDDO
      DEALLOCATE ( rhog_unsrt )
      CALL mp_sum ( rhog, intra_pool_comm )
      gvec ( :, : ) = 0
      DO ig = 1, ngm
        gvec ( 1, ig_l2g ( ig ) ) = mill ( 1, ig )
        gvec ( 2, ig_l2g ( ig ) ) = mill ( 2, ig )
        gvec ( 3, ig_l2g ( ig ) ) = mill ( 3, ig )
      ENDDO
      CALL mp_sum ( gvec, intra_pool_comm )
    ENDIF

    DO is = 1, ns
      DO ig = 1, ngm
        rho%of_g ( ig, is ) = rhog ( ig_l2g ( ig ), is )
      ENDDO
    ENDDO

    DEALLOCATE ( rhog )

    DO is = 1, ns
      DO ig = 1, ngm
        psic ( dfftp%nl ( ig ) ) = rho%of_g ( ig, is )
      ENDDO
      CALL invfft ( 'Rho', psic, dfftp )
      DO ir = 1, dfftp%nnr
        rho%of_r ( ir, is ) = psic ( ir )
      ENDDO
    ENDDO

    ! CALL create_directory ( output_dir_name )

    ! filename = TRIM ( output_dir_name ) // '/gvectors.dat'

    ! IF ( ionode ) THEN
    !   CALL iotk_open_write ( iu, FILE = TRIM ( filename ), SKIP_ROOT = .TRUE., BINARY = .TRUE. )
    !   CALL iotk_write_begin ( iu, "G-VECTORS" )
    !   CALL iotk_write_attr ( attr, "nr1s", dfftp%nr1, FIRST = .TRUE. )
    !   CALL iotk_write_attr ( attr, "nr2s", dfftp%nr2 )
    !   CALL iotk_write_attr ( attr, "nr3s", dfftp%nr3 )
    !   CALL iotk_write_attr ( attr, "gvect_number", ng )
    !   CALL iotk_write_attr ( attr, "gamma_only", .FALSE. )
    !   CALL iotk_write_attr ( attr, "units", "crystal" )
    !   CALL iotk_write_empty ( iu, "INFO", ATTR = attr )
    !   CALL iotk_write_dat ( iu, "g", gvec ( 1 : 3, 1 : ng ), COLUMNS = 3 )
    !   CALL iotk_write_end ( iu, "G-VECTORS" )
    !   CALL iotk_close_write ( iu )
    ! ENDIF

    DEALLOCATE ( gvec )

    ! CALL write_rho ( output_dir_name, rho%of_r, nspin )
    prefix = TRIM(prefix)//"_newrho"    
    CALL write_scf(rho, nspin)

    RETURN

    101 FORMAT ( 5X, "WARNING: reordering G-vectors" )

  END SUBROUTINE write_cd

  !-------------------------------------------------------------------------------

  subroutine check_inversion(real_or_complex, ntran, mtrx, nspin, warn, real_need_inv)

    ! check_inversion    Originally By D. Strubbe    Last Modified 10/14/2010
    ! Check whether our choice of real/complex version is appropriate given the
    ! presence or absence of inversion symmetry.

    USE io_global, ONLY : ionode

    implicit none

    integer, intent(in) :: real_or_complex
    integer, intent(in) :: ntran
    integer, intent(in) :: mtrx(3, 3, 48)
    integer, intent(in) :: nspin
    logical, intent(in) :: warn ! set to false to suppress warnings, for converters
    logical, intent(in) :: real_need_inv ! use for generating routines to block real without inversion

    integer :: invflag, isym, ii, jj, itest

    invflag = 0
    do isym = 1, ntran
       itest = 0
       do ii = 1, 3
          do jj = 1, 3
             if(ii .eq. jj) then
                itest = itest + (mtrx(ii, jj, isym) + 1)**2
             else
                itest = itest + mtrx(ii, jj, isym)**2
             endif
          enddo
       enddo
       if(itest .eq. 0) invflag = invflag + 1
       if(invflag .gt. 1) call errore('check_inversion', 'More than one inversion symmetry operation is present.', invflag)
    enddo

    if(real_or_complex .eq. 2) then
       if(invflag .ne. 0 .and. warn) then
          if(ionode) write(6, '(a)') 'WARNING: Inversion symmetry is present. The real version would be faster.'
       endif
    else
       if(invflag .eq. 0) then
          if(real_need_inv) then
             call errore('check_inversion', 'The real version cannot be used without inversion symmetry.', -1)
          endif
          if(ionode) then
             write(6, '(a)') 'WARNING: Inversion symmetry is absent in symmetries used to reduce k-grid.'
             write(6, '(a)') 'Be sure inversion is still a spatial symmetry, or you must use complex version instead.'
          endif
       endif
       if(nspin .eq. 2) then
          call errore('check_inversion', &
               'Time-reversal symmetry is absent in spin-polarized calculation. Complex version must be used.', -2)
       endif
    endif

    return

  end subroutine check_inversion

  !-------------------------------------------------------------------------------

END PROGRAM bgw2pw
