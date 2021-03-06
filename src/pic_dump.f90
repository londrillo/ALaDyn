 !*****************************************************************************************************!
 !                            Copyright 2008-2018  The ALaDyn Collaboration                            !
 !*****************************************************************************************************!

 !*****************************************************************************************************!
 !  This file is part of ALaDyn.                                                                       !
 !                                                                                                     !
 !  ALaDyn is free software: you can redistribute it and/or modify                                     !
 !  it under the terms of the GNU General Public License as published by                               !
 !  the Free Software Foundation, either version 3 of the License, or                                  !
 !  (at your option) any later version.                                                                !
 !                                                                                                     !
 !  ALaDyn is distributed in the hope that it will be useful,                                          !
 !  but WITHOUT ANY WARRANTY; without even the implied warranty of                                     !
 !  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                                      !
 !  GNU General Public License for more details.                                                       !
 !                                                                                                     !
 !  You should have received a copy of the GNU General Public License                                  !
 !  along with ALaDyn.  If not, see <http://www.gnu.org/licenses/>.                                    !
 !*****************************************************************************************************!

 module pic_dump

 use precision_def
 use pstruct_data
 use fstruct_data
 use all_param
 use parallel

 implicit none

 real(dp),allocatable ::send_buff(:),recv_buff(:)
 contains
!----------------------
 subroutine dump_data(it_loc,tloc)
 integer,intent(in) :: it_loc
 real(dp),intent(in) :: tloc
 character(9) :: fname='         '
 character(9) :: fname_yz='         '
 character(9) :: fname_ebf='         '
 character(9) :: fname_env='         '
 character(9) :: fname_fl='         '
 character(9) :: fname_part='         '
 character(11) :: fnamel_part='           '
 character(11) :: fnamel_ebf ='           '
 character(11) :: fnamel_env ='           '
 character(11) :: fnamel_fl ='           '
 character(11) :: foldername='           '
 character(25) :: fname_out='                         '
 character(27) :: fnamel_out='                           '
 
 
 integer(offset_kind) :: disp,disp_col
 integer :: max_npt_size
 integer :: np,ic,lun,i,j,k,kk,ipe,lenbuff
 integer :: nxf_loc,nyf_loc,nzf_loc,ndv
 integer :: npt_arr(npe,nsp),ip_loc(npe)
 integer :: loc_grid_size(npe),loc2d_grid_size(npe),lenw(npe)
 integer :: grid_size_max,grid2d_size_max
 integer :: env_cp,env1_cp,fl_cp,ebf_cp
 real(dp) :: rdata(10)
 integer :: ndata(10),nps_loc(4)
 integer :: dist_npy(npe_yloc,nsp),dist_npz(npe_zloc,nsp)
 !==============
 write (fname,'(a9)') 'Comm-data'
 write (fname_yz,'(a9)') 'Dist-wgyz'
 write (fname_ebf,'(a9)') 'EB-fields'
 write (fname_env,'(a9)') 'ENVfields'
 write (fname_fl,'(a9)') 'FL-fields'
 write (fname_part,'(a9)') 'Particles'
 write (foldername,'(a11)')'dumpRestart'
!================field array sizes
 nxf_loc=size(ebf,1)
 nyf_loc=size(ebf,2)
 nzf_loc=size(ebf,3)
 ebf_cp=size(ebf,4)

 loc_grid_size(mype+1)=nxf_loc*nyf_loc*nzf_loc  !allowing for different grid sizes among mpi_tasks
 loc2d_grid_size(mype+1)=nyf_loc*nzf_loc 
 lenbuff=ebf_cp

 env_cp=0
 env1_cp=0
 fl_cp=0
 ndv=0
 if(Envelope)then
  env_cp=size(env,4)
  if(Two_color)env1_cp=env_cp
  lenbuff=max(lenbuff,env_cp+env1_cp)
 endif
 grid2d_size_max=0
 if(Hybrid)then
  fl_cp=size(up,4)
  lenbuff=max(lenbuff,2*fl_cp)
  kk=loc2d_grid_size(mype+1)
  call intvec_distribute(kk,loc2d_grid_size,npe)  
  grid2d_size_max=maxval(loc2d_grid_size(1:npe))
 endif
!===============================
 kk=loc_grid_size(mype+1)
 call intvec_distribute(kk,loc_grid_size,npe)  
 grid_size_max=maxval(loc_grid_size(1:npe))
 lenbuff=lenbuff*grid_size_max+grid2d_size_max
!===============================
 if(Part)then
  ndv=size(ebfp,2)
  do i=1,nsp
   nps_loc(i)=size(spec(i)%part,1)
   kk=loc_npart(imody,imodz,imodx,i)
   call intvec_distribute(kk,ip_loc,npe)  
   npt_arr(1:npe,i)=ip_loc(1:npe)
  end do
  do i=1,npe
   ip_loc(i)=sum(npt_arr(i,1:nsp))
  end do
  max_npt_size=ndv*maxval(ip_loc(1:npe))
  lenbuff=max(lenbuff,max_npt_size)
!=============================
  dist_npy(:,:)=0
  dist_npz(:,:)=0
  dist_npy(imody+1,1:nsp)=loc_npty(1:nsp)
  dist_npz(imodz+1,1:nsp)=loc_nptz(1:nsp)
  if(imody >0)then
   call mpi_send(loc_npty,nsp,mpi_integer,pe0y,100+imody, &
   comm_col(1),error)
  else
   do ipe=1,npe_yloc-1
    call mpi_recv(loc_npty,nsp,mpi_integer,ipe,100+ipe, &
    comm_col(1),status,error)
    dist_npy(ipe+1,1:nsp)=loc_npty(1:nsp)
   end do
  endif
  if(imodz >0)then
   call mpi_send(loc_nptz,nsp,mpi_integer,pe0z,10+imodz, &
   comm_col(2),error)
  else
   do ipe=1,npe_zloc-1
    call mpi_recv(loc_nptz,nsp,mpi_integer,ipe,10+ipe, &
    comm_col(2),status,error)
    dist_npz(ipe+1,1:nsp)=loc_nptz(1:nsp)
   end do
  endif
!===================
 endif
!=========================
 ndata=0
 rdata=0.0
!====================
 rdata(1)=tloc
 rdata(2)=j0_norm
 rdata(3)=ompe
 rdata(4)=targ_in
 rdata(5)=targ_end
 rdata(6)=lp_in(1)
 rdata(7)=xp0_out
 rdata(8)=xp1_out
 rdata(9)=x(1)

 ndata(1)=it_loc
 ndata(2)=nxf_loc
 ndata(3)=nyf_loc
 ndata(4)=nzf_loc
 ndata(5)=nptx_max
 ndata(6)=size(x)
 ndata(7)=nxf
 ndata(8)=nd2
!==========================
 lun=10
 if(pe0)then
  open(lun,file='dumpRestart/'//fname//'.bin',form='unformatted',status='unknown')
  write(lun)rdata(1:10)
  write(lun)ndata(1:10)
  write(lun)nptx(1:nsp)
  write(lun)sptx_max(1:nsp)
!=====================
  if(targ_end > xmax)then
   do i=1,nsp
    do j=1,nptx_max
     write(lun)xpt(j,i),wghpt(j,i)
    end do
   end do
   if(Hybrid)then
    if(nxf >0)then
     write(lun)fluid_x_profile(1:nxf)
    endif
   endif
  endif
  if(Part)then
   write(lun)npt_arr(1:npe,1:nsp)
   write(lun)dist_npy(1:npe_yloc,1:nsp)
   write(lun)dist_npz(1:npe_zloc,1:nsp)
  endif
!==================
  close(lun)
 endif       !end pe0 write on fname
 if(pe0)write(6,*)'End write Common data'
!===========================
 allocate(send_buff(lenbuff))     !to be used for all mpi_write()
!=====================
 if(Part)then
  write (fnamel_part,'(a9,i2.2)') 'Particles',imodz
  fnamel_out='dumpRestart/'//fnamel_part//'.bin'
  lenw(1:npe)=ndv*ip_loc(1:npe)
  max_npt_size=maxval(lenw(1:npe))
  kk=0
  do ic=1,nsp
   np=loc_npart(imody,imodz,imodx,ic)
   if(np >0)then
    do j=1,ndv
     do i=1,np
      kk=kk+1
      send_buff(kk)=spec(ic)%part(i,j)
     end do
    end do
   endif
  end do
  disp_col=0
  if(MOD(mype,npe_yloc) > 0)disp_col=sum(lenw(imodz*npe_yloc+1:mype)) 
  disp_col=8*disp_col
  call mpi_write_col_dp(send_buff,lenw(mype+1),disp_col,27,fnamel_out)
  if(pe0)write(6,*)'Particles data dumped'
 endif
!===============================
 write (fnamel_ebf,'(a9,i2.2)') 'EB-fields',imodz
 fnamel_out='dumpRestart/'//fnamel_ebf//'.bin'
 lenw(1:npe)=ebf_cp*loc_grid_size(1:npe)
 kk=0
 do ic=1,ebf_cp
  do k=1,nzf_loc
   do j=1,nyf_loc
    do i=1,nxf_loc
     kk=kk+1
     send_buff(kk)=ebf(i,j,k,ic)
    end do
   end do
  end do
 end do

 disp=lenw(1+mype)
 disp_col=imody*disp
 disp_col=8*disp_col
 call mpi_write_col_dp(send_buff,lenw(1+mype),disp_col,27,fnamel_out)
 if(pe0)write(6,*)'Electromagnetic fields data dumped'
 !========================
 if(envelope)then
  write (fnamel_env,'(a9,i2.2)') 'ENVfields',imodz
  fnamel_out='dumpRestart/'//fnamel_env//'.bin'
  lenw(1:npe)=(env_cp+env1_cp)*loc_grid_size(1:npe)
  kk=0
  do ic=1,env_cp
   do k=1,nzf_loc
    do j=1,nyf_loc
     do i=1,nxf_loc
      kk=kk+1
      send_buff(kk)=env(i,j,k,ic)
     end do
    end do
   end do
  end do
  if(Two_color)then
   do ic=1,env1_cp
    do k=1,nzf_loc
     do j=1,nyf_loc
      do i=1,nxf_loc
       kk=kk+1
       send_buff(kk)=env1(i,j,k,ic)
      end do
     end do
    end do
   end do
  endif
  disp=lenw(1+mype)
  disp_col=imody*disp
  disp_col=8*disp_col
  call mpi_write_col_dp(send_buff,lenw(mype+1),disp_col,27,fnamel_out)
 if(pe0)write(6,*)'Envelope field data dumped'
 endif
 !===============================
 if(Hybrid)then
  write (fnamel_fl,'(a9,i2.2)')'FL-fields',imodz
  fnamel_out='dumpRestart/'//fnamel_fl//'.bin'
  lenw(1:npe)=2*fl_cp*loc_grid_size(1:npe)+loc2d_grid_size(1:npe)
  kk=0
  do k=1,nzf_loc
   do j=1,nyf_loc
    kk=kk+1
    send_buff(kk)=fluid_yz_profile(j,k)
   end do
  end do
  do ic=1,fl_cp
   do k=1,nzf_loc
    do j=1,nyf_loc
     do i=1,nxf_loc
      kk=kk+1
      send_buff(kk)=up(i,j,k,ic)
     end do
    end do
   end do
  end do
  do ic=1,fl_cp
   do k=1,nzf_loc
    do j=1,nyf_loc
     do i=1,nxf_loc
      kk=kk+1
      send_buff(kk)=up0(i,j,k,ic)
     end do
    end do
   end do
  end do
  disp=lenw(1+mype)
  disp_col=imody*disp
  disp_col=8*disp_col
  call mpi_write_col_dp(send_buff,lenw(1+mype),disp_col,27,fnamel_out)
 if(pe0)write(6,*)'Fluid density and momentum data dumped'
 endif
!============== write (y,z,wghyz initial part distribution
 if(Part)then
  fname_out='dumpRestart/'//fname_yz//'.bin'
  kk=0
  do ic=1,nsp
   if(loc_npty(ic)>0)then
    do i=1,loc_npty(ic)
     kk=kk+1
     send_buff(kk)=loc_ypt(i,ic)
    end do
   endif
  enddo
  do ic=1,nsp
   if(loc_nptz(ic)>0)then
    do j=1,loc_nptz(ic)
     kk=kk+1
     send_buff(kk)=loc_zpt(j,ic)
    end do
   endif
  end do
!===============================
  do ic=1,nsp
   if(loc_nptz(ic)>0)then
    do j=1,loc_nptz(ic)
     if(loc_npty(ic)>0)then
      do i=1,loc_npty(ic)
       kk=kk+1
       send_buff(kk)=loc_wghyz(i,j,ic)
      end do
     endif
    end do
   endif
  end do
  call intvec_distribute(kk,lenw,npe)  
  disp=0
  if(mype >0)disp=sum(lenw(1:mype))
  disp=8*disp
  call mpi_write_dp(send_buff,lenw(mype+1),disp,25,fname_out)
  if(pe0)write(6,*)'Incoming plasma target transverse distribution data dumped'
 endif
 deallocate(send_buff)
!====================
 unix_time_last_dump = unix_time_now
 if(pe0)write(6,*)'END TOTAL DUMP WRITE'
 end subroutine dump_data
 !==============================================================

 subroutine restart(it_loc,tloc)
 integer,intent(out) :: it_loc
 real(dp),intent(out) :: tloc
 character(9) :: fname='         '
 character(9) :: fname_yz='         '
 character(9) :: fname_ebf='         '
 character(9) :: fname_env='         '
 character(9) :: fname_fl='         '
 character(9) :: fname_part='         '
 character(11) :: fnamel_part='           '
 character(11) :: fnamel_ebf ='           '
 character(11) :: fnamel_env ='           '
 character(11) :: fnamel_fl ='           '
 character(11) :: foldername='           '
 character(25) :: fname_out='                         '
 character(27) :: fnamel_out='                           '
 integer(offset_kind) :: disp,disp_col
 integer :: max_npt_size,ipe,npt_arr(npe,nsp)
 integer :: np,ic,lun,i,j,k,kk,k1,lenw(npe),lenbuff
 integer :: ndv
 integer :: ip_loc(npe),loc_grid_size(npe),loc2d_grid_size(npe)
 integer :: grid_size_max,grid2d_size_max
 integer :: env_cp,env1_cp,fl_cp,ebf_cp
 integer :: ndata(10),nps_loc(4),np_max,n1_old
 integer :: n1_loc,n2_loc,n3_loc,nypt_max,nzpt_max
 integer :: dist_npy(npe_yloc,nsp),dist_npz(npe_zloc,nsp)
 real(dp) :: rdata(10),x0_new
 
 !==============
 write (fname,'(a9)') 'Comm-data'
 write (fname_ebf,'(a9)') 'EB-fields'
 write (fname_env,'(a9)') 'ENVfields'
 write (fname_fl,'(a9)') 'FL-fields'
 write (fname_part,'(a9)') 'Particles'
 write (foldername,'(a11)')'dumpRestart'
 write (fname_yz,'(a9)') 'Dist-wgyz'
 !==============       Already defined data
 n1_loc=size(ebf,1)
 n2_loc=size(ebf,2)
 n3_loc=size(ebf,3)
 ebf_cp=size(ebf,4)
!===================
 loc_grid_size(mype+1)=n1_loc*n2_loc*n3_loc
 loc2d_grid_size(mype+1)=n2_loc*n3_loc
 lenbuff=ebf_cp
 env_cp=0
 env1_cp=0
 fl_cp=0
 if(Envelope)then
  env_cp=size(env,4)
  if(Two_color)env1_cp=size(env1,4)
  lenbuff=max(lenbuff,env_cp+env1_cp)
 endif
 grid2d_size_max=0
 if(Hybrid)then
  fl_cp=size(up,4)
  lenbuff=max(lenbuff,2*fl_cp)
  kk=loc2d_grid_size(mype+1)
  call intvec_distribute(kk,loc2d_grid_size,npe)  
  grid2d_size_max=maxval(loc2d_grid_size(1:npe))
 endif
 kk=loc_grid_size(mype+1)
 call intvec_distribute(kk,loc_grid_size,npe)  
 grid_size_max=maxval(loc_grid_size(1:npe))
 lenbuff=lenbuff*grid_size_max+grid2d_size_max
!===================
 if(pe0)write(6,*)'Max size of recieve buffer',lenbuff
 lun=10
 if(pe0)then
 open (lun,file='dumpRestart/'//fname//'.bin',form='unformatted',status='unknown')
  read(lun)rdata(1:10)
  read(lun)ndata(1:10)
  read(lun)nptx(1:nsp)
  read(lun)sptx_max(1:nsp)
  it_loc=ndata(1)
  nptx_max=ndata(5)
  n1_old=ndata(6)
  nxf=ndata(7)
  ndv=ndata(8)+1
!=========================
  tloc=rdata(1)
  targ_in=rdata(4)
  targ_end=rdata(5)
  lp_in(1)=rdata(6)
  x0_new= rdata(9)
 !=============================
  if(targ_end > xmax+x0_new)then
   allocate(xpt(nptx_max,nsp))
   allocate(wghpt(nptx_max,nsp))
   do i=1,nsp
    do j=1,nptx_max
     read(lun)xpt(j,i),wghpt(j,i)
    end do
   end do
   if(Hybrid)then
    if(nxf>0)then
     allocate(fluid_x_profile(nxf))
     read(lun)fluid_x_profile(1:nxf)
    endif
   endif
  endif
  if(Part)then
   read(lun)npt_arr(1:npe,1:nsp)
   read(lun)dist_npy(1:npe_yloc,1:nsp)
   read(lun)dist_npz(1:npe_zloc,1:nsp)
  endif
  close(lun)
 endif               !end pe0 read on fname
!========================= distribute comm data
 kk=size(rdata)
 k1=size(ndata)
 call mpi_bcast(ndata,k1,mpi_integer,pe_min,comm,error)
 call mpi_bcast(nptx,nsp,mpi_integer,pe_min,comm,error)
 call mpi_bcast(sptx_max,nsp,mpi_integer,pe_min,comm,error)
 call mpi_bcast(rdata,kk,mpi_sd,pe_min,comm,error)

 it_loc=ndata(1)
 nptx_max=ndata(5)
 n1_old=ndata(6)
 nxf=ndata(7)
 ndv=ndata(8)+1
!=========================
 tloc=rdata(1)
 targ_in=rdata(4)
 targ_end=rdata(5)
 lp_in(1)=rdata(6)
 x0_new= rdata(9)
 if(x0_new>0.0)then
  x=x+x0_new
  xh=xh+x0_new
  xmin=xmin+x0_new
  xmax=xmax+x0_new
  loc_xgrid(imodx)%gmin=loc_xgrid(imodx)%gmin+x0_new
  loc_xgrid(imodx)%gmax=loc_xgrid(imodx)%gmax+x0_new
  xp0_out=xp0_out+x0_new
  xp1_out=xp1_out+x0_new
 endif
 if(targ_end > xmax)then
  if(mype >0)then
   allocate(xpt(nptx_max,nsp))
   allocate(wghpt(nptx_max,nsp))
   if(Hybrid)then
    if(nxf >0)allocate(fluid_x_profile(nxf))
   endif
  endif
  if(pe0)then
   do ipe=1,npe-1
    call mpi_send(xpt(1,1),nptx_max*nsp,mpi_double_precision,ipe,100+ipe,&
    comm,error)
    call mpi_send(wghpt(1,1),nptx_max*nsp,mpi_double_precision,ipe,400+ipe,&
    comm,error)
   enddo
  else
   call mpi_recv(xpt(1,1),nptx_max*nsp,mpi_double_precision,pe_min,100+mype,&
   comm,status,error)
   call mpi_recv(wghpt(1,1),nptx_max*nsp,mpi_double_precision,pe_min,400+mype,&
   comm,status,error)
  endif
!===========================
  if(Hybrid)then
   if(nxf>0)then
    if(pe0)then
     do ipe=1,npe-1
      call mpi_send(fluid_x_profile(1),nxf,mpi_double_precision,ipe,10+ipe,&
      comm,error)
     enddo
    else
     call mpi_recv(fluid_x_profile(1),nxf,mpi_double_precision,pe_min,10+mype,&
     comm,status,error)
    endif
   endif
  endif
 endif
 if(Part)then                 !distributes npart => npt(npe,nsp)
  call mpi_bcast(npt_arr(1,1),npe*nsp,mpi_integer,pe_min,comm,error)
  do i=1,npe
   ip_loc(i)=sum(npt_arr(i,1:nsp))
  enddo
  max_npt_size=ndv*maxval(ip_loc(1:npe))
  lenbuff=max(lenbuff,max_npt_size)
  ipe=0
   do i=0,npe_xloc-1
    do j=0,npe_zloc-1
     do k=0,npe_yloc-1
      loc_npart(k,j,i,1:nsp)=npt_arr(ipe+1,1:nsp)
      ipe=ipe+1
     end do
    end do
   end do
!========== distributes npty,nptz initial particle distribution
  call mpi_bcast(dist_npy(1,1),npe_yloc*nsp,mpi_integer,pe_min,comm,error)
  call mpi_bcast(dist_npz(1,1),npe_zloc*nsp,mpi_integer,pe_min,comm,error)
  loc_npty(1:nsp)=dist_npy(imody+1,1:nsp)
  loc_nptz(1:nsp)=dist_npz(imodz+1,1:nsp)
  nypt_max=maxval(loc_npty(1:nsp))
  nzpt_max=maxval(loc_nptz(1:nsp))
  allocate(loc_ypt(nypt_max,nsp))
  allocate(loc_zpt(nzpt_max,nsp))
  allocate(loc_wghyz(nypt_max,nzpt_max,nsp))
 endif    !end n_part distribut
 ! x() defined on the grid module starting from x(1)=0.0
!---------- Particle read
!============================================
 allocate(recv_buff(lenbuff))
 recv_buff(:)=0.0
!============================================
 if(Hybrid)then
  write (fnamel_fl,'(a9,i2.2)') 'FL-fields',imodz
  fnamel_out='dumpRestart/'//fnamel_fl//'.bin'
  lenw(1:npe)=2*fl_cp*loc_grid_size(1:npe)+loc2d_grid_size(1:npe)
!==========================
  disp=lenw(1+mype)
  disp_col=imody*disp
  disp_col=8*disp_col
  call mpi_read_col_dp(recv_buff,lenw(1+mype),disp_col,27,fnamel_out)
  kk=0
  do k=1,n3_loc
   do j=1,n2_loc
    kk=kk+1
    fluid_yz_profile(j,k)=recv_buff(kk)
   end do
  end do
  do ic=1,fl_cp
   do k=1,n3_loc
    do j=1,n2_loc
     do i=1,n1_loc
      kk=kk+1
      up(i,j,k,ic)=recv_buff(kk)
     end do
    end do
   end do
  end do
  do ic=1,fl_cp
   do k=1,n3_loc
    do j=1,n2_loc
     do i=1,n1_loc
      kk=kk+1
      up0(i,j,k,ic)=recv_buff(kk)
     end do
    end do
   end do
  end do
  if(pe0)write(6,*)'Fluid density and momentum data read'
 endif
!================
 if(envelope)then
  write (fnamel_env,'(a9,i2.2)') 'ENVfields',imodz
  fnamel_out='dumpRestart/'//fnamel_env//'.bin'
  lenw(1:npe)=(env_cp+env1_cp)*loc_grid_size(1:npe)
!==================
  disp=lenw(1+mype)
  disp_col=imody*disp
  disp_col=8*disp_col
  call mpi_read_col_dp(recv_buff,lenw(1+mype),disp_col,27,fnamel_out)
!======================
  kk=0
  do ic=1,env_cp
   do k=1,n3_loc
    do j=1,n2_loc
     do i=1,n1_loc
      kk=kk+1
      env(i,j,k,ic)=recv_buff(kk)
     end do
    end do
   end do
  end do
  if(Two_color)then
   do ic=1,env1_cp
    do k=1,n3_loc
     do j=1,n2_loc
      do i=1,n1_loc
       kk=kk+1
       env1(i,j,k,ic)=recv_buff(kk)
      end do
     end do
    end do
   end do
  endif
  if(pe0)write(6,*)'Envelope field data read'
 endif
!--------------------- FIELD DUMP READ
 write (fnamel_ebf,'(a9,i2.2)') 'EB-fields',imodz
 fnamel_out='dumpRestart/'//fnamel_ebf//'.bin'
 lenw(1:npe)=ebf_cp*loc_grid_size(1:npe)
!=========================
 disp=lenw(1+mype)
 disp_col=imody*disp
 disp_col=8*disp_col
 call mpi_read_col_dp(recv_buff,lenw(1+mype),disp_col,27,fnamel_out)
!===========================
 kk=0
 do ic=1,ebf_cp
  do k=1,n3_loc
   do j=1,n2_loc
    do i=1,n1_loc
     kk=kk+1
     ebf(i,j,k,ic)=recv_buff(kk)
    end do
   end do
  end do
 end do
 if(pe0)write(6,*)'Electromagnetic fields data read'
!=========================
 if(Part)then
  write (fnamel_part,'(a9,i2.2)') 'Particles',imodz
  fnamel_out='dumpRestart/'//fnamel_part//'.bin'
  do i=1,nsp
   nps_loc(i)=maxval(npt_arr(1:npe,i))
  end do
  np_max=maxval(nps_loc(1:nsp))
  call p_alloc(np_max,ndv,nps_loc,nsp,LPf_ord,1,1,mem_psize)
  lenw(1:npe)=ndv*ip_loc(1:npe)
!=======================
  disp_col=0
  if(MOD(mype,npe_yloc) > 0)disp_col=sum(lenw(imodz*npe_yloc+1:mype)) 
  disp_col=8*disp_col
  call mpi_read_col_dp(recv_buff,lenw(1+mype),disp_col,27,fnamel_out)
!==============================
  kk=0
  do ic=1,nsp
   np=loc_npart(imody,imodz,imodx,ic)
   if(np >0)then
    do j=1,ndv
     do i=1,np
      kk=kk+1
      spec(ic)%part(i,j)=recv_buff(kk)
     end do
    end do
   endif
  end do
 endif
!=================================
 if(Part)then
  fname_out='dumpRestart/'//fname_yz//'.bin'
  kk=0
  do ic=1,nsp
   if(loc_npty(ic) >0)then
    do i=1,loc_npty(ic)
     kk=kk+1
    end do
   endif
  end do
  do ic=1,nsp
   if(loc_nptz(ic) >0)then
    do j=1,loc_nptz(ic)
     kk=kk+1
    end do
   endif
  end do
  do ic=1,nsp
   if(loc_nptz(ic) >0)then
    do j=1,loc_nptz(ic)
     if(loc_npty(ic) >0)then
      do i=1,loc_npty(ic)
       kk=kk+1
      end do
     endif
    end do
   endif
  end do
  call intvec_distribute(kk,lenw,npe)  
  disp=0
  if(mype >0)disp=sum(lenw(1:mype))
  disp=8*disp
  call mpi_read_dp(recv_buff,lenw(mype+1),disp,25,fname_out)
  kk=0
  do ic=1,nsp
   do i=1,loc_npty(ic)
    kk=kk+1
    loc_ypt(i,ic)=recv_buff(kk)
   end do
  enddo
  do ic=1,nsp
   do j=1,loc_nptz(ic)
    kk=kk+1
    loc_zpt(j,ic)=recv_buff(kk)
   end do
  end do
  do ic=1,nsp
   do j=1,loc_nptz(ic)
    do i=1,loc_npty(ic)
     kk=kk+1
     loc_wghyz(i,j,ic)=recv_buff(kk)
    end do
   end do
  end do
  if(pe0)write(6,*)'Particles data read'
 endif                   !end of part read
!============================================
 deallocate(recv_buff)
!===============================
 if(pe0)write(6,*)'END TOTAL DUMP READ'
 end subroutine restart
 !===========================
 end module pic_dump
 !===================================
