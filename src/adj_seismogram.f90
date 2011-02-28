
!========================================================================
!
!                   S P E C F E M 2 D  Version 6.1
!                   ------------------------------
!
! Copyright Universite de Pau, CNRS and INRIA, France,
! and Princeton University / California Institute of Technology, USA.
! Contributors: Dimitri Komatitsch, dimitri DOT komatitsch aT univ-pau DOT fr
!               Nicolas Le Goff, nicolas DOT legoff aT univ-pau DOT fr
!               Roland Martin, roland DOT martin aT univ-pau DOT fr
!               Christina Morency, cmorency aT princeton DOT edu
!
! This software is a computer program whose purpose is to solve
! the two-dimensional viscoelastic anisotropic or poroelastic wave equation
! using a spectral-element method (SEM).
!
! This software is governed by the CeCILL license under French law and
! abiding by the rules of distribution of free software. You can use,
! modify and/or redistribute the software under the terms of the CeCILL
! license as circulated by CEA, CNRS and INRIA at the following URL
! "http://www.cecill.info".
!
! As a counterpart to the access to the source code and rights to copy,
! modify and redistribute granted by the license, users are provided only
! with a limited warranty and the software's author, the holder of the
! economic rights, and the successive licensors have only limited
! liability.
!
! In this respect, the user's attention is drawn to the risks associated
! with loading, using, modifying and/or developing or reproducing the
! software by the user in light of its specific status of free software,
! that may mean that it is complicated to manipulate, and that also
! therefore means that it is reserved for developers and experienced
! professionals having in-depth computer knowledge. Users are therefore
! encouraged to load and test the software's suitability as regards their
! requirements in conditions enabling the security of their systems and/or
! data to be ensured and, more generally, to use and operate it in the
! same conditions as regards security.
!
! The full text of the license is available in file "LICENSE".
!
!========================================================================

      program adj_seismogram

! This program cuts a certain portion of the seismograms and convert it
! into the adjoint source for generating banana-dougnut kernels

      implicit none
!
!!!!  user edit
      integer, parameter :: NSTEP = 3000
      integer, parameter :: nrec = 1
      double precision, parameter :: t0 = 12
      double precision, parameter :: deltat = 6d-2
      double precision, parameter :: EPS = 1.d-40
!!!!
      integer :: itime,icomp,istart,iend,nlen,irec,NDIM,NDIMr,adj_comp
      double precision :: time,tstart(nrec),tend(nrec)
      character(len=150), dimension(nrec) :: station_name
      double precision, dimension(NSTEP) :: time_window
      double precision :: seism(NSTEP,3),Nnorm,seism_win(NSTEP)
      double precision :: seism_veloc(NSTEP),seism_accel(NSTEP),ft_bar(NSTEP)
      character(len=3) :: compr(2),comp(3)
      character(len=150) :: filename,filename2

      NDIM=3
      comp = (/"BHX","BHY","BHZ"/)

!!!! user edit
! which calculation: P-SV (use (1)) or SH (membrane) (use (2)) waves
      NDIMr=2  !(1)
!      NDIMr=1  !(2)
! list of stations
      station_name(1) = 'S0001'
      tstart(1) = 100d0 + t0
      tend(1) = 120d0 + t0
! which calculation: P-SV (use (1)) or SH (membrane) (use (2)) waves
      compr = (/"BHX","BHZ"/)    !(1)
!      compr = (/"BHY","dummy"/)  !(2)
! chose the component for the adjoint source (adj_comp = 1: X, 2:Y, 3:Z)
      adj_comp = 1
!!!!

      do irec =1,nrec

        do icomp = 1, NDIMr

      filename = 'OUTPUT_FILES/'//trim(station_name(irec))//'.AA.'// compr(icomp) // '.semd'
      open(unit = 10, file = trim(filename))

         do itime = 1,NSTEP
        read(10,*) time , seism(itime,icomp)
         enddo

        enddo

          if(NDIMr==2)then
           seism(:,3) = seism(:,2)
           seism(:,2) = 0.d0
          else
           seism(:,2) = seism(:,1)
           seism(:,1) = 0.d0
           seism(:,3) = 0.d0
          endif

      close(10)


         istart = max(floor(tstart(irec)/deltat),1)
         iend = min(floor(tend(irec)/deltat),NSTEP)
         print*,'istart =',istart, 'iend =', iend
         print*,'tstart =',istart*deltat, 'tend =', iend*deltat
         if(istart >= iend) stop 'check istart,iend'
         nlen = iend - istart +1

       do icomp = 1, NDIM

      print*,comp(icomp)

      filename = 'OUTPUT_FILES/'//trim(station_name(irec))//'.AA.'// comp(icomp) // '.adj'
      open(unit = 11, file = trim(filename))

        time_window(:) = 0.d0
        seism_win(:) = seism(:,icomp)
        seism_veloc(:) = 0.d0
        seism_accel(:) = 0.d0

        do itime =istart,iend
!        time_window(itime) = 1.d0 - cos(pi*(itime-1)/NSTEP+1)**10   ! cosine window
        time_window(itime) = 1.d0 - (2* (dble(itime) - istart)/(iend-istart) -1.d0)**2  ! Welch window
        enddo

         do itime = 2,NSTEP-1
      seism_veloc(itime) = (seism_win(itime+1) - seism_win(itime-1))/(2*deltat)
         enddo
      seism_veloc(1) = (seism_win(2) - seism_win(1))/deltat
      seism_veloc(NSTEP) = (seism_win(NSTEP) - seism_win(NSTEP-1))/deltat

         do itime = 2,NSTEP-1
      seism_accel(itime) = (seism_veloc(itime+1) - seism_veloc(itime-1))/(2*deltat)
         enddo
      seism_accel(1) = (seism_veloc(2) - seism_veloc(1))/deltat
      seism_accel(NSTEP) = (seism_veloc(NSTEP) - seism_veloc(NSTEP-1))/deltat

      Nnorm = deltat * sum(time_window(:) * seism_win(:) * seism_accel(:))
!      Nnorm = deltat * sum(time_window(:) * seism_veloc(:) * seism_veloc(:))
! cross-correlation traveltime adjoint source
      if(abs(Nnorm) > EPS) then
!      ft_bar(:) = - seism_veloc(:) * time_window(:) / Nnorm
      ft_bar(:) = seism_veloc(:) * time_window(:) / Nnorm
      print*,'Norm =', Nnorm
      else
      print *, 'norm < EPS for file '
      print*,'Norm =', Nnorm
      ft_bar(:) = 0.d0
      endif

       do itime =1,NSTEP
        if(icomp == adj_comp) then
      write(11,*) (itime-1)*deltat - t0, ft_bar(itime)
        else
      write(11,*) (itime-1)*deltat - t0, 0.d0
        endif
       enddo

        enddo
      close(11)

      enddo
      print*,'*************************'
      print*,'The input files (S****.AA.BHX/BHY/BHZ.adj) needed to run the adjoint simulation are in OUTPUT_FILES'
      print*,'*************************'

      end program adj_seismogram