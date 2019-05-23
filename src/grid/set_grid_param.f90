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
 !===================================================
 !     Local grid structure under mpi domain decomposition
 !============== 
 ! grid [1:n]   np=n+2  extended domain [1:np+2]
 ! interior [3,np]   ghost [1:2], [np+1:np+2]  
 ! overlapping grid  structure:
 !             
 !====================================================================
 !                                     1-----2---- 3--- 4   |      pey+1
 !                 1-----2----[3-------np-1--np]--np+1--np+2|    pey
 !1-2--------------np-1--np---np+1                          |pey-1
 !======================================================================
 !      Right(pey+1)     [1:4]     overlap pey [np-1:np+2]
 !      Left(pey-1)      [np-1:np+2]overlap pey [1:4]
 !===================================


 module set_grid_param

 use common_param
 use grid_param
 use mpi_var

 implicit none

 contains

 !--------------------------
 ! allocates and defines global (x,y,z)coordinates for uniform or stretched
 ! configurations
 !--------------------------
 subroutine set_grid(n1,n2,n3,ib,x_stretch,y_stretch,xres,yxres,zxres)
 integer,intent(in) :: n1,n2,n3,ib,x_stretch,y_stretch
 real(dp),intent(in) :: xres,yxres,zxres
 integer :: i,ns1
 real(dp) :: yy,yyh,sm,sp

 allocate(x(n1+1),xw(n1+1),dx1(n1+1),y(n2+1),z(n3+1),dy1(n2+1),dz1(n3+1))
 allocate(dx1h(n1+1),dy1h(n2+1),dz1h(n3+1))
 allocate(xh(n1+1),yh(n2+1),zh(n3+1))
!-----------------------------------
 aph=acos(-1.0)*0.4
 dxi=1.
 dyi=1.
 dzi=1.
 sx_rat=1.
 sy_rat=1.
 sz_rat=1.
 sm=0.0
 sp=0.0
 dx=1.
 if(xres>0.0)dx=1./xres
 dx_inv=1.0/dx
 do i=1,n1+1
  x(i)=dx*real(i-1,dp)    !xminx(1)=0,.....,xmax-dx=x(nx)
  xh(i)=x(i)+0.5*dx
  dx1(i)=1.
  dx1h(i)=1.
 end do
 dxi=dx
 dxi_inv=dx_inv
 ns1=n1+1-x_stretch
 if(x_stretch >0)then
  dxi=aph/real(x_stretch,dp)
  dxi_inv=1./dxi
  Lx_s=dx*dxi_inv
  sx_rat=dxi*dx_inv
  sp=x(ns1)
  do i=ns1,n1+1
   yy=dxi*real(i-ns1,dp)
   yyh=yy+dxi*0.5
   x(i)=sp+Lx_s*tan(yy)
   xh(i)=sp+Lx_s*tan(yyh)
   dx1h(i)=cos(yyh)*cos(yyh)
   dx1(i)=cos(yy)*cos(yy)
  end do
 endif
 str_xgrid%sind(1)=x_stretch
 str_xgrid%sind(2)=ns1
 str_xgrid%smin=x(1)
 str_xgrid%smax=x(ns1)
 xw=x
 xmax=x(n1)
 xmin=x(1)
 if(ib==2)xmax=x(n1+1)
 Lx_box=xmax-xmin
 xw_min=xmin
 xw_max=xmax

 dy=1.
 dy_inv=1./dy
 dyi=dy
 dyi_inv=1./dy
 ymin=0.0
 ymax=0.0
 y=0.0
 yh=0.0
 dy1=1.
 dy1h=1.
 Ly_box=1.
 if(n2 > 1)then
  dy=yxres*dx
  dy_inv=1./dy
  dyi=dy
  dyi_inv=dy_inv
  do i=1,n2+1
   y(i)=dy*real(i-1-n2/2,dp)
   yh(i)=y(i)+0.5*dy
   dy1(i)=1.
   dy1h(i)=1.
  end do
!============== Stretched grid 
!   index      [1:y_stretch]              [ns1:n2+1] 
!   coordinate [y(1): sm=y(y_stretch+1]   [sp: y(n2+1)=ymax]
!   unstretched: [y_stretch+1:ns1-1=n2+1-(y_stretch1)]
!========================
  ns1=n2+1-y_stretch
  if(y_stretch>0)then
   dyi=aph/real(y_stretch,dp)
   dyi_inv=1./dyi
   L_s=dy*dyi_inv
   sy_rat=dyi*dy_inv
   sm=y(y_stretch+1)
   sp=y(ns1)
   str_ygrid%sind(1)=y_stretch
   str_ygrid%sind(2)=ns1
   str_ygrid%smin=sm
   str_ygrid%smax=sp
   do i=1,y_stretch
    yy=dyi*real(i-1-y_stretch,dp)
    yyh=yy+0.5*dyi
    y(i)=sm+L_s*tan(yy)          !y(xi)=y_s +(Dy/Dxi)*tan(xi) Dy=L_s*dxi uniform
    yh(i)=sm+L_s*tan(yyh)
    dy1h(i)=cos(yyh)*cos(yyh)    ! dy(xi)= L_s/cos^2(xi)=(Dy/Dxi)/cos^2(xi) 
    dy1(i)=cos(yy)*cos(yy)       ! dy1=cos^2(xi)=(dy/dxi)^{-1}*(Dy0/Dxi)
   end do
   do i=ns1,n2+1
    yy=dyi*real(i-ns1,dp)
    yyh=yy+dyi*0.5
    y(i)=sp+L_s*tan(yy)
    yh(i)=sp+L_s*tan(yyh)
    dy1h(i)=cos(yyh)*cos(yyh)
    dy1(i)=cos(yy)*cos(yy)
   end do
  endif
  ymin=y(1)
  ymax=y(n2+1)
  Ly_box=ymax-ymin
 endif
 dz=1.
 dz_inv=1./dz
 dzi=dz
 dzi_inv=1./dz
 zmin=0.0
 zmax=0.0
 z=0.0
 zh=0.0
 dz1=1.
 dz1h=1.
 Lz_box=1.
 if(n3 > 1)then
  dz=zxres*dx
  dz_inv=1./dz
  do i=1,n3+1
   z(i)=dz*real(i-1-n3/2,dp)
   zh(i)=z(i)+0.5*dz
   dz1(i)=1.
   dz1h(i)=1.
  end do
  ns1=n3+1-y_stretch
  if(y_stretch>0)then
   dzi=aph/real(y_stretch,dp)
   dzi_inv=1./dzi
   L_s=dz*dzi_inv
   sz_rat=dzi*dz_inv
   sm=z(y_stretch+1)
   sp=z(ns1)
   str_zgrid%sind(1)=y_stretch
   str_zgrid%sind(2)=ns1
   str_zgrid%smin=sm
   str_zgrid%smax=sp
   do i=1,y_stretch
    yy=dzi*real(i-1-y_stretch,dp)
    yyh=yy+0.5*dzi
    z(i)=sm+L_s*tan(yy)
    zh(i)=sm+L_s*tan(yyh)
    dz1h(i)=cos(yyh)*cos(yyh)
    dz1(i)=cos(yy)*cos(yy)
   end do
   do i=ns1,n3+1
    yy=dzi*real(i-ns1,dp)
    yyh=yy+dzi*0.5
    z(i)=sp+L_s*tan(yy)
    zh(i)=sp+L_s*tan(yyh)
    dz1h(i)=cos(yyh)*cos(yyh)
    dz1(i)=cos(yy)*cos(yy)
   end do
  endif
  zmin=z(1)
  zmax=z(n3+1)
  Lz_box=zmax-zmin
 endif
 end subroutine set_grid
 !================
 !================
  subroutine mpi_loc_grid(n1_loc,n2_loc,n3_loc,npex,npey,npez)

  integer,intent(in) :: n1_loc,n2_loc,n3_loc,npex,npey,npez
  integer :: p

   allocate(loc_ygrid(0:npey-1),loc_zgrid(0:npez-1))
   allocate(loc_xgrid(0:npex-1))

   loc_xgr_max=n1_loc
   do p=0,npex-1
    loc_xgrid(p)%ng=n1_loc
   end do
   loc_ygr_max=n2_loc
    loc_zgr_max=n3_loc
    do p=0,npey-1
     loc_ygrid(p)%ng=n2_loc
    end do
     do p=0,npez-1
      loc_zgrid(p)%ng=n3_loc
     end do
    allocate(nxh(npex),nyh(npey),nzh(npez))

    allocate(loc_yg(0:loc_ygr_max+1,4,0:npey-1))
    allocate(loc_zg(0:loc_zgr_max+1,4,0:npez-1))
   allocate(loc_xg(0:loc_xgr_max+1,4,0:npex-1))

   allocate(str_indx(0:npey-1,0:npez-1))
   str_indx(0:npey-1,0:npez-1)=0

 end subroutine mpi_loc_grid

 subroutine set_output_grid(jmp,npex,npey,npez)

 integer,intent(in) :: jmp,npex,npey,npez
 integer :: i1,j1,k1,i2,j2,k2
 integer :: ipe,ix,ix1,iy1,iz1,ngyzx(3),ngout

 do ipe= 0,npex-1
  i1=loc_xgrid(ipe)%p_ind(1)
  i2=loc_xgrid(ipe)%p_ind(2)
  ix1=0
  do ix=i1,i2,jmp
   ix1=ix1+1
  enddo
  nxh(ipe+1)=ix1
 enddo
 do ipe= 0,npey-1
  j1=loc_ygrid(ipe)%p_ind(1)
  j2=loc_ygrid(ipe)%p_ind(2)
  iy1=0
  do ix=j1,j2,jmp
   iy1=iy1+1
  enddo
  nyh(ipe+1)=iy1
 enddo
 do ipe= 0,npez-1
  k1=loc_zgrid(ipe)%p_ind(1)
  k2=loc_zgrid(ipe)%p_ind(2)
  iz1=0
  do ix=k1,k2,jmp
   iz1=iz1+1
  enddo
  nzh(ipe+1)=iz1
 enddo
 ngout=max(nx,ny)
 ngout=max(ngout,nz)
 allocate(gwdata(ngout)) !
  ngyzx(1)=maxval(nyh(1:npey))
  ngyzx(2)=maxval(nzh(1:npez))
  ngyzx(3)=maxval(nxh(1:npex))
  ngout=ngyzx(1)*ngyzx(2)*ngyzx(3)
  if(ngout > 0)then
   allocate(wdata(ngout))
  else
   allocate(wdata(1))
  endif

 end subroutine set_output_grid

 subroutine set_fyzxgrid(npey,npez,npex,sh)
 integer,intent(in) :: npey,npez,npex,sh
 integer :: i,ii,p,ip,n_loc

 ! Defines initial local p-grid coordinate and loc n_cell
 ! y-grid decomposed on n2_loc uniform grid size
 loc_ygrid(0)%gmin=y(1)
 ip=loc_ygrid(0)%ng
 n_loc=ip
 loc_ygrid(0)%gmax=y(ip+1)
 loc_ygrid(0)%p_ind(1)=min(sh,n_loc)
 loc_ygrid(0)%p_ind(2)=n_loc+loc_ygrid(0)%p_ind(1)-1

 p=0
 do i=1,n_loc+1
  loc_yg(i,1,p)=y(i)
  loc_yg(i,2,p)=yh(i)
  loc_yg(i,3,p)=dy1(i)
  loc_yg(i,4,p)=dy1h(i)
 end do

 if(npey >1)then
  ip=loc_ygrid(0)%ng
  if(npey >2) then
   do p=1,npey-2
    n_loc=loc_ygrid(p-1)%ng
    loc_yg(0,1:4,p)=loc_yg(n_loc,1:4,p-1)
    n_loc=loc_ygrid(p)%ng
    do i=1,n_loc+1
     ii=i+ip
     loc_yg(i,1,p)=y(ii)
     loc_yg(i,2,p)=yh(ii)
     loc_yg(i,3,p)=dy1(ii)
     loc_yg(i,4,p)=dy1h(ii)
    end do
    loc_ygrid(p)%gmin=loc_ygrid(p-1)%gmax

    ip=ip+n_loc
    loc_ygrid(p)%gmax=y(ip+1)

    loc_ygrid(p)%p_ind(1)=sh
    loc_ygrid(p)%p_ind(2)=n_loc+loc_ygrid(p)%p_ind(1)-1

   end do
  endif
  p=npey-1
  n_loc=loc_ygrid(p-1)%ng
  loc_yg(0,1:4,p)=loc_yg(n_loc,1:4,p-1)
  n_loc=loc_ygrid(p)%ng
  do i=1,n_loc+1
   ii=i+ip
   loc_yg(i,1,p)=y(ii)
   loc_yg(i,2,p)=yh(ii)
   loc_yg(i,3,p)=dy1(ii)   ! dy1=cos^2(xi) =[dxi/dy] stretched  (=1 y=xi)
   loc_yg(i,4,p)=dy1h(ii)

  end do
  loc_ygrid(p)%gmin=loc_ygrid(p-1)%gmax
  ip=ip+n_loc
  loc_ygrid(p)%gmax=y(ip+1)
  loc_ygrid(p)%p_ind(1)=sh
  loc_ygrid(p)%p_ind(2)=n_loc+loc_ygrid(p)%p_ind(1)-1

 endif
 !=========================
 loc_zgrid(0)%gmin=z(1)
 ip=loc_zgrid(0)%ng
 n_loc=ip
 loc_zgrid(0)%gmax=z(ip+1)
 loc_zgrid(0)%p_ind(1)=min(sh,n_loc)
 loc_zgrid(0)%p_ind(2)=n_loc+loc_zgrid(0)%p_ind(1)-1

 p=0
 do i=1,n_loc+1
  loc_zg(i,1,p)=z(i)
  loc_zg(i,2,p)=zh(i)
  loc_zg(i,3,p)=dz1(i)
  loc_zg(i,4,p)=dz1h(i)
 end do

 if(npez >1)then
  ip=loc_zgrid(0)%ng
  if(npez >2) then
   do p=1,npez-2
    n_loc=loc_zgrid(p-1)%ng
    loc_zg(0,1:4,p)=loc_zg(n_loc,1:4,p-1)
    n_loc=loc_zgrid(p)%ng
    do i=1,n_loc+1
     ii=i+ip
     loc_zg(i,1,p)=z(ii)
     loc_zg(i,2,p)=zh(ii)
     loc_zg(i,3,p)=dz1(ii)
     loc_zg(i,4,p)=dz1h(ii)
    end do
    loc_zgrid(p)%gmin=loc_zgrid(p-1)%gmax
    ip=ip+n_loc
    loc_zgrid(p)%gmax=z(ip+1)
    loc_zgrid(p)%p_ind(1)=sh
    loc_zgrid(p)%p_ind(2)=n_loc+loc_zgrid(p)%p_ind(1)-1
   end do
  endif
  p=npez-1
  n_loc=loc_zgrid(p-1)%ng
  loc_zg(0,1:4,p)=loc_zg(n_loc,1:4,p-1)
  n_loc=loc_zgrid(p)%ng
  do i=1,n_loc+1
   ii=i+ip
   loc_zg(i,1,p)=z(ii)
   loc_zg(i,2,p)=zh(ii)
   loc_zg(i,3,p)=dz1(ii)
   loc_zg(i,4,p)=dz1h(ii)
  end do
  loc_zgrid(p)%gmin=loc_zgrid(p-1)%gmax
  ip=ip+n_loc
  loc_zgrid(p)%gmax=z(ip+1)
  loc_zgrid(p)%p_ind(1)=sh
  loc_zgrid(p)%p_ind(2)=n_loc+loc_zgrid(p)%p_ind(1)-1
 endif
 !======================
 loc_xgrid(0)%gmin=x(1)
 ip=loc_xgrid(0)%ng
 n_loc=ip
 loc_xgrid(0)%gmax=x(ip+1)
 loc_xgrid(0)%p_ind(1)=min(sh,n_loc)
 loc_xgrid(0)%p_ind(2)=n_loc+loc_xgrid(0)%p_ind(1)-1

 p=0
 do i=1,n_loc+1
  loc_xg(i,1,p)=x(i)
  loc_xg(i,2,p)=xh(i)
  loc_xg(i,3,p)=dx1(i)
  loc_xg(i,4,p)=dx1h(i)
 end do

 if(npex >1)then
  ip=loc_xgrid(0)%ng
  if(npex >2) then
   do p=1,npex-2
    n_loc=loc_xgrid(p-1)%ng
    loc_xg(0,1:4,p)=loc_xg(n_loc,1:4,p-1)
    n_loc=loc_xgrid(p)%ng
    do i=1,n_loc+1
     ii=i+ip
     loc_xg(i,1,p)=x(ii)
     loc_xg(i,2,p)=xh(ii)
     loc_xg(i,3,p)=dx1(ii)
     loc_xg(i,4,p)=dx1h(ii)
    end do
    loc_xgrid(p)%gmin=loc_xgrid(p-1)%gmax
    ip=ip+n_loc
    loc_xgrid(p)%gmax=x(ip+1)
    loc_xgrid(p)%p_ind(1)=sh
    loc_xgrid(p)%p_ind(2)=n_loc+loc_xgrid(p)%p_ind(1)-1
   end do
  endif
  p=npex-1
  n_loc=loc_xgrid(p-1)%ng
  loc_xg(0,1:4,p)=loc_xg(n_loc,1:4,p-1)
  n_loc=loc_xgrid(p)%ng
  do i=1,n_loc+1
   ii=i+ip
   loc_xg(i,1,p)=x(ii)
   loc_xg(i,2,p)=xh(ii)
   loc_xg(i,3,p)=dx1(ii)
   loc_xg(i,4,p)=dx1h(ii)
  end do
  loc_xgrid(p)%gmin=loc_xgrid(p-1)%gmax
  ip=ip+n_loc
  loc_xgrid(p)%gmax=x(ip+1)
  loc_xgrid(p)%p_ind(1)=sh
  loc_xgrid(p)%p_ind(2)=n_loc+loc_xgrid(p)%p_ind(1)-1
 endif
 end subroutine set_fyzxgrid
 !======================
 subroutine set_fxgrid(npex,sh)
 integer,intent(in) :: npex,sh
 integer :: i,ii,p,ip,n_loc

 loc_xgrid(0)%gmin=x(1)
 ip=loc_xgrid(0)%ng
 n_loc=ip
 loc_xgrid(0)%gmax=x(ip+1)
 loc_xgrid(0)%p_ind(1)=min(sh,n_loc)
 loc_xgrid(0)%p_ind(2)=n_loc+loc_xgrid(0)%p_ind(1)-1

 p=0
 do i=1,n_loc+1
  loc_xg(i,1,p)=x(i)
  loc_xg(i,2,p)=xh(i)
  loc_xg(i,3,p)=dx1(i)
  loc_xg(i,4,p)=dx1h(i)
 end do

 if(npex >1)then
  ip=loc_xgrid(0)%ng
  if(npex >2) then
   do p=1,npex-2
    n_loc=loc_xgrid(p-1)%ng
    loc_xg(0,1:4,p)=loc_xg(n_loc,1:4,p-1)
    n_loc=loc_xgrid(p)%ng
    do i=1,n_loc+1
     ii=i+ip
     loc_xg(i,1,p)=x(ii)
     loc_xg(i,2,p)=xh(ii)
     loc_xg(i,3,p)=dx1(ii)
     loc_xg(i,4,p)=dx1h(ii)
    end do
    loc_xgrid(p)%gmin=loc_xgrid(p-1)%gmax
    ip=ip+n_loc
    loc_xgrid(p)%gmax=x(ip+1)
    loc_xgrid(p)%p_ind(1)=sh
    loc_xgrid(p)%p_ind(2)=n_loc+loc_xgrid(p)%p_ind(1)-1
   end do
  endif
  p=npex-1
  n_loc=loc_xgrid(p-1)%ng
  loc_xg(0,1:4,p)=loc_xg(n_loc,1:4,p-1)
  n_loc=loc_xgrid(p)%ng
  do i=1,n_loc+1
   ii=i+ip
   loc_xg(i,1,p)=x(ii)
   loc_xg(i,2,p)=xh(ii)
   loc_xg(i,3,p)=dx1(ii)
   loc_xg(i,4,p)=dx1h(ii)
  end do
  loc_xgrid(p)%gmin=loc_xgrid(p-1)%gmax
  ip=ip+n_loc
  loc_xgrid(p)%gmax=x(ip+1)
  loc_xgrid(p)%p_ind(1)=sh
  loc_xgrid(p)%p_ind(2)=n_loc+loc_xgrid(p)%p_ind(1)-1
 endif
 end subroutine set_fxgrid

 subroutine set_str_ind(npey,npez,ndm)
 integer,intent(in) :: npey,npez,ndm
 integer :: p,q,ip(4)

 str_indx(0:npey-1,0:npez-1)=0
 ip=0
 if(ndm <3)then
  do p=0,npey-1
   if(str_ygrid%smin >loc_ygrid(p)%gmin)ip(1)=p
   if(str_ygrid%smax >= loc_ygrid(p)%gmin)ip(2)=p
  end do

  p=0
  do q=0,ip(1)
   str_indx(q,p)=1      !selects mpi-tasks with stretched y< 0 up to ys_min
  end do
  do q=ip(2),npey-1
   str_indx(q,p)=2      !selects mpi-tasks with stretched y>0 up to ys_max
  end do
  return
 endif
 do p=0,npey-1
  if(str_ygrid%smin > loc_ygrid(p)%gmin)ip(1)=p
  if(str_ygrid%smax >= loc_ygrid(p)%gmin)ip(2)=p
 end do
 do p=0,npez-1
  if(str_zgrid%smin >loc_zgrid(p)%gmin)ip(3)=p
  if(str_zgrid%smax >=loc_zgrid(p)%gmin)ip(4)=p
 end do

 do p=0,ip(3)
  str_indx(0:npey-1,p)=2
  do q=0,ip(1)
   str_indx(q,p)=1
  end do
  do q=ip(2),npey-1
   str_indx(q,p)=3
  end do
 end do
 do p=ip(3)+1,ip(4)-1
  do q=0,ip(1)
   str_indx(q,p)=8
  end do
  do q=ip(2),npey-1
   str_indx(q,p)=4
  end do
 end do
 do p=ip(4),npez-1
  str_indx(0:npey-1,p)=6
  do q=0,ip(1)
   str_indx(q,p)=7
  end do
  do q=ip(2),npey-1
   str_indx(q,p)=5
  end do
 end do
 end subroutine set_str_ind

 subroutine set_loc_grid_param

  xmn=loc_xgrid(imodx)%gmin
  ymn=loc_ygrid(imody)%gmin
  zmn=loc_zgrid(imodz)%gmin
  ix1=loc_xgrid(imodx)%p_ind(1)
  ix2=loc_xgrid(imodx)%p_ind(2)
  jy1=loc_ygrid(imody)%p_ind(1)
  jy2=loc_ygrid(imody)%p_ind(2)
  kz1=loc_zgrid(imodz)%p_ind(1)
  kz2=loc_zgrid(imodz)%p_ind(2)
  n_str=0
  if(Stretch)n_str=str_indx(imody,imodz)

  nyp =loc_ygrid(imody)%p_ind(2)  !Ny_loc+2
  nzp= loc_zgrid(imodz)%p_ind(2)    !Nz_loc+2
  nxp= loc_xgrid(imodx)%p_ind(2)    !Nx_loc+2

 end subroutine set_loc_grid_param
!=====
 !--------------------------

 !--------------------------
 subroutine set_ftgrid(n1,n2,n3)
  integer,intent(in) :: n1,n2,n3
  integer :: i
  real(dp) :: wkx,wky,wkz


  allocate(aky(n2+2,0:2),akz(n3+2,0:2))
  allocate(sky(n2+2,0:2),skz(n3+2,0:2))
  allocate(ak2y(n2+2,0:2),ak2z(n3+2,0:2),ak2x(n1+1,0:2))
  allocate(akx(1:n1+1,0:2),skx(1:n1+1,0:2))
  akx(:,0:2)=0.0
  ak2x(:,0:2)=0.0
  aky(:,0:2)=0.0
  ak2y(:,0:2)=0.0
  akz(:,0:2)=0.0
  ak2z(:,0:2)=0.0
  skx(:,0:2)=0.0
  sky(:,0:2)=0.0
  skz(:,0:2)=0.0
!================
!  Sets wave number grid for all configurations
!=============================================
                    !case(0)  ! staggered k-grid
 wkx=2.*acos(-1.)/lx_box !lxbox=x(n1+1)-x(1)
 wky=2.*acos(-1.)/ly_box !lybox=y(n2+1)-y(1)
 wkz=wky
  do i=1,n1/2
   akx(i,0)=wkx*(real(i,dp)-0.5)
   skx(i,0)=2.*sin(0.5*dx*akx(i,0))/dx
  end do
  ak2x(1:n1,0)=akx(1:n1,0)*akx(1:n1,0)
  if(n2>1)then
   do i=1,n2/2
    aky(i,0)=wky*(real(i,dp)-0.5)
    aky(n2+1-i,0)=-aky(i,0)
   end do
   ak2y(1:n2,0)=aky(1:n2,0)*aky(1:n2,0)
   do i=1,n2
    sky(i,0)=2.*sin(0.5*dy*aky(i,0))/dy
   end do
  endif
  if(n3 >1)then
   do i=1,n3/2
    akz(i,0)=wkz*(real(i,dp)-0.5)
    akz(n3+1-i,0)=-akz(i,0)
   end do
   do i=1,n3
    skz(i,0)=2.*sin(0.5*dz*akz(i,0))/dz
   end do
   ak2z(1:n3,0)=akz(1:n3,0)*akz(1:n3,0)
  endif

                      !case(1)    !standard FT k-grid
  do i=1,n1/2
   akx(i,1)=wkx*real(i-1,dp)
   akx(n1+2-i,1)=-akx(i,1)
  end do
  ak2x(1:n1,1)=akx(1:n1,1)*akx(1:n1,1)
  do i=1,n1+1
   skx(i,1)=2.*sin(0.5*dx*akx(i,1))/dx
  end do
  if(n2 > 1)then
   do i=1,n2/2
    aky(i,1)=wky*real(i-1,dp)
    aky(n2+2-i,1)=-aky(i,1)
    sky(i,1)=2.*sin(0.5*dy*aky(i,1))/dy
   end do
   ak2y(1:n2,1)=aky(1:n2,1)*aky(1:n2,1)
  endif
  if(n3 > 1)then
   do i=1,n3/2
    akz(i,1)=wkz*real(i-1,dp)
    akz(n3+2-i,1)=-akz(i,1)
   end do
   do i=1,n3
    skz(i,1)=2.*sin(0.5*dz*akz(i,1))/dz
   end do
   ak2z(1:n3,1)=akz(1:n3,1)*akz(1:n3,1)
  endif

                         !case(2)  ! for the sine/cosine transform
  wkx=acos(-1.0)/lx_box
  wky=acos(-1.0)/ly_box
  wkz=wky
  do i=1,n1+1
   akx(i,2)=wkx*real(i-1,dp)
   skx(i,2)=2.*sin(0.5*dx*akx(i,2))/dx
  end do
  if(n2>1)then
   do i=1,n2+1
    aky(i,2)=wky*real(i-1,dp)
    sky(i,2)=2.*sin(0.5*dy*aky(i,2))/dy
   end do
   ak2y(1:n2,2)=aky(1:n2,2)*aky(1:n2,2)
  endif
  if(n3 >1)then
   do i=1,n3+1
    akz(i,2)=wkz*real(i-1,dp)
    skz(i,2)=2.*sin(0.5*dz*akz(i,2))/dz
   end do
   ak2z(1:n3,2)=akz(1:n3,2)*akz(1:n3,2)
  endif
 end subroutine set_ftgrid
!=============================
 end module set_grid_param