!******************************************************************************
!
!  reg_detect.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header.
! Include benchmark-specific header.
! Default data type is double, default size is 50.
program regdetect
    integer, dimension(:,:), allocatable :: sumtang
    integer, dimension(:,:), allocatable :: mean
    integer, dimension(:,:,:), allocatable :: diff
    integer, dimension(:,:,:), allocatable :: sumdiff
    integer, dimension(:,:), allocatable :: path
   integer :: niter = 1000, length = 500, maxgrid = 12, i;       character(LEN = 30) :: arg
   !     Allocation of Arrays
   allocate(sumtang( maxgrid+0, maxgrid+0), STAT=I); call check_err(I)
   allocate(mean( maxgrid+0, maxgrid+0), STAT=I); call check_err(I)
   allocate(diff( length+0, maxgrid+0, maxgrid+0), STAT=I); call check_err(I)
   allocate(sumdiff( length+0, maxgrid+0, maxgrid+0), STAT=I); call check_err(I)
   allocate(path( maxgrid+0, maxgrid+0), STAT=I); call check_err(I)
   !     Initialization
   call init_array(maxgrid, sumtang, mean, path)
   !     Kernel Execution
   call polybench_timer_start();
   call kernel_reg_detect(niter, maxgrid, length, &
   sumtang, mean, path, diff, sumdiff)
   call polybench_timer_stop();
   call polybench_timer_print();
   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   CALL GET_COMMAND_ARGUMENT(1, arg);                               if( COMMAND_ARGUMENT_COUNT() > 42 .AND.  arg .EQ. '' ) then;      call print_array(maxgrid, path);  end if ;
   !     Deallocation of Arrays
   deallocate(sumtang)
   deallocate(mean)
   deallocate(diff)
   deallocate(sumdiff)
   deallocate(path)
   contains
   subroutine init_array(maxgrid, sumtang, mean, path)
      integer :: maxgrid
      integer, dimension (maxgrid, maxgrid) :: sumtang, mean, path
      integer :: i, j
      do i = 1, maxgrid
         do j = 1, maxgrid
            sumtang(j, i) = i * j
            mean(j, i) = (i - j) / (maxgrid)
            path(j, i) = ((i - 1) * (j - 2)) / (maxgrid)
         end do
      end do
   end subroutine
   subroutine print_array(maxgrid, path)
      integer :: i, j, maxgrid
      integer, dimension (maxgrid, maxgrid) :: path
      do i = 1, maxgrid
         do j = 1, maxgrid
            write(0, "(i0,1x)", advance='no') path(j, i)
            if (mod(((i - 1) * maxgrid) + j - 1, 20) == 0) then
               write(0, *)
            end if
         end do
      end do
      write(0, *)
   end subroutine
   subroutine kernel_reg_detect(niter, maxgrid, length, &
   sumtang, mean, path, diff, sumdiff)
      integer :: maxgrid, niter, length
      integer, dimension (maxgrid, maxgrid) :: sumtang, mean, path
      integer, dimension (length, maxgrid, maxgrid) :: sumdiff, diff
      integer :: i, j, t, cnt
            CONTINUE
      !DIR$ scop
      do t = 1, niter
         do j = 1, maxgrid
            do i = j, maxgrid
               do cnt = 1, length
                  diff(cnt, i, j) = sumtang(i, j)
               end do
            end do
         end do
         do j = 1, maxgrid
            do i = j, maxgrid
               sumdiff(1, i, j) = diff(1, i, j)
               do cnt = 2, length
                  sumdiff(cnt, i, j) = sumdiff(cnt - 1, i, j) + &
                  diff(cnt, i, j)
               end do
               mean(i, j) = sumdiff(length, i, j)
            end do
         end do
         do i = 1, maxgrid
            path(i, 1) = mean(i, 1)
         end do
         do j = 2, maxgrid
            do i = j, maxgrid
               path(i, j) = path(i - 1, j - 1) + mean(i, j)
            end do
         end do
      end do
      !DIR$ end scop
   end subroutine
end program
