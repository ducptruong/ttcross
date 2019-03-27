program main
 use tt_lib
 use ttaux_lib
 use dmrgg_lib
 use time_lib
 use quad_lib
 use mat_lib
 use omp_lib
 implicit none
 include 'mpif.h'
 type(dtt) :: tt,qq
 integer :: i,j,p,m,n,nx,r,piv,decay,info,nproc,me,adj
 integer(kind=8) :: neval
 double precision :: f,bnd,t1,t2,tcrs, einf,efro,ainf,afro, acc,val,tru,h,w,t
 integer,allocatable :: own(:)
 double precision,allocatable::par(:),mat(:,:)
 double precision,parameter :: tpi=6.2831853071795864769252867665590057683943387987502116419498891846156328125724179972560696506842341359642961730265646132941876892191011644634507188162569622349005682054038770422111192892458979098607639288576219513318668922569512964675735663305424038182912971338469206972209086532964267872145204982825474491740132126311763497630418419256585081834307287357851807200226610610976409330427682939038830232188661145407315191839061843722347638652235862102370961489247599254991347037715054497824558763660238982596673467248813132861720427898927904494743814043597218874055410784343525863535047693496369353388102640011362542905271216555715426855155792183472743574429368818024499068602930991707421015845593785178470840399122242580439217280688363196272595495426199210374144226999999967459560999021194634656321926371900489189106938166052850446165066893700705238623763420200062756775057731750664167628412343553382946071965069808575109374623191257277647075751875039155637155610643424536132260038557532223918184328403d0
 double precision,parameter :: log2=0.6931471805599453094172321214581765680755001343602552541206800094933936219696947156058633269964186875420014810205706857336855202357581305570326707516350759619307275708283714351903070386238916734711233501153644979552391204751726815749320651555247341395258829504530070953263666426541042391578149520437404303855008019441706416715186447128399681717845469570262716310645461502572074024816377733896385506952606683411372738737229289564935470257626520988596932019650585547647033067936544325476327449512504060694381471046899465062201677204245245296126879465461931651746813926725041038025462596568691441928716082938031727143677826548775664850856740776484514644399404614226031930967354025744460703080960850474866385231381816767514386674766478908814371419854942315199735488037516586127535291661000710535582498794147295092931138971559982056543928717000721808576102523688921324497138932037843935308877482597017155910708823683627589842589185353024363421436706118923678919237231467232172053401649256872747782344535d0
 double precision,parameter :: zeta3=1.202056903159594285399738161511449990764986292340498881792271555341838205786313090186455873609335258146199157795260719418491995998673283213776396837207900161453941782949360066719191575522242494243961563909664103291159095780965514651279918405105715255988015437109781102039827532566787603522336984941661811057014715778639499737523785277937030956025701853182790003076547107563048843320869711573742380793445031607625317714535444411831178182249718526357091824489987962035083357561720226033937858703281312678079900541773486911525370656237057440966221712902627320732361492242913040528555372341033077577798064242024304882815210009146026538220696271552020822743350010152948011986901176259516763669981718355752348807037195557423472940835952088616662025728537558130792825864872821737055661968989526620187768106292008177923381358768284264124324314802821736745067206935076268953043459393750329663637757506247332399234828831077339052768020075798435679371150509005027366047114008533503436467224856531518117766181092d0
 character(len=1) :: a
 character(len=32) :: aa
 logical :: rescale
 double precision,external :: dfunc_ising_discr

 ! Read params
 call getarg(1,aa); read(aa,'(a1)')a  ; if (a.eq.' ')a='C'      ! dimension of the problem
 call getarg(2,aa); read(aa,'(i10)') m; if (m.eq.0)  m=6        ! dimension of the problem
 call getarg(3,aa); read(aa,'(i10)') n; if (n.eq.0)  n=65       ! stoch. mode size
 call getarg(4,aa); read(aa,'(i10)') r; if (r.eq.0)  r=10       ! max rank
 call getarg(5,aa); read(aa,'(i10)') piv;   ! pivoting strategy

 call mpi_init(info)
 if(info.ne.0)then;write(*,*)'mpi: init fail: ',info;stop;endif
 call mpi_comm_size(MPI_COMM_WORLD,nproc,info)
 if(info.ne.0)then;write(*,*)'mpi: comm_size fail: ',info;stop;endif
 call mpi_comm_rank(MPI_COMM_WORLD,me,info)
 if(info.ne.0)then;write(*,*)'mpi: comm_rank fail: ',info;stop;endif
 !write(*,'(a,i3,a,i3)')'mpi: I am ',me,' of ',nproc
 allocate(own(0:nproc))

 adj=0
 if(mod(n,2).eq.0)then;n=n+1;adj=1;endif
 if(me.eq.0)then
  write(*,'(a)') 'Hi, this is TT cross interpolation computing Ising integral...'
  write(*,'(3x,a,a10)') 'integral :',a
  write(*,'(3x,a,i10)') 'dimension:',m
  if(adj.eq.0)then
   write(*,'(3x,a,i10)') 'quadratur:',n
  else 
   write(*,'(3x,a,i10,a)') 'quadratur:',n,' (adjusted)'
  end if 
  write(*,'(3x,a,i10)') 'TT ranks :',r
  write(*,'(3x,a,i10)') 'pivoting :',piv
  write(*,'(3x,a,i10)') 'MPI procs:',nproc
!$OMP PARALLEL
  if (omp_get_thread_num().eq.0) then
   write(*,'(3x,a,i10)')'OMP thrds:', omp_get_num_threads()
  end if 
!$OMP END PARALLEL
  write(*,'(3x,a,i10)') 'sizeof(d):',storage_size(1.d0)
  write(*,'(3x,a,e10.3)') 'epsilon  :',epsilon(1.d0)
 end if
 acc=500*epsilon(1.d0)

 allocate(par(2*n+1), stat=info)
 if(info.ne.0)then;write(*,*)'cannot allocate par:',info;stop;endif
 if(a.eq.'c' .or. a.eq.'C')then;par(2*n+1)=dble(1)
 elseif(a.eq.'d' .or. a.eq.'D')then;par(2*n+1)=dble(2)
 elseif(a.eq.'e' .or. a.eq.'E')then;par(2*n+1)=dble(3)
 else;write(*,*)'unknown integral type:',a;stop
 endif
 ! benchmark data from http://crd-legacy.lbl.gov/~dhbailey/dhbpapers/ising-data.pdf
 tru=0.d0
 if(a.eq.'c' .or. a.eq.'C')then
  if(m.eq.2)tru=1.d0
  if(m.eq.3)tru=0.781302412896486296867187429624092356365134336545285420222100062966886984651618218092869570832209861021042350256509035768865870552440307999260784419989574930756967213098085932160953364386339574767285839770325515898564777091242889924100249818885371308788489523887682281593269542022747136358189370747905938376851614621789917792086036135302394227603825064226268305457310112035525726489104581114952725398024966799796445479960266333365842227594600553537176562282562396301698967938757682094583043d0
  if(m.eq.4)tru=0.701199860176429999816513927548345827946242003865291014378825073949405620042015969275432592938778900585282842047235419660786997665892748541369564821704608427514799373387126705586195085721308121642310912280637393586509472538896550213246619069645000565993009004980705642856566060663959435388029907882636056449925250870873041513555541412129934724348326081023294168461319146078445158603840665084683055462842935104448102000145675906901520606312335807041636897619159644520465291911003465186463750d0
  !if(m.eq.4)tru=7.d0*zeta3/12
  if(m.eq.5)tru=0.665759800199937428315733808307066598197496382079497659539442703531227043767212347867719015080369293085843994924311856040349259330050753680563866874740905560747140475488234106631293810299787665392898786664777785180019463299184220278288193097196758824449732632712025332032810335336148039317399267758108295728228998742819914700151136779304930675335567050463603362881698629003102931186422293874562420020653938654692999022769820476988108975539537698724896975392962446560796426596437505074037855d0
  if(m.eq.6)tru=0.648634209031007075263149843450351690889772509481627995615050887184781781788005579236825162435086788746305778560263980277015360622851077728813219046451864230224915877848383017478321796815352205732838648138639825586469363423412767765471547690778987140184450398227188078510672232859625126042823172524203615573983985503276614388340979251772333917206044051956366130011314392900329279058188727223104746584973807329108710283312363982723838220861655573557737841536232012512857683488361001999048111d0
  if(m.eq.8)tru=0.635484026759163226139684899936898393485446063736278309835724508002389169032937027339756684064043523541244586304149729548068352148088167360413521310658994950955040048385245590379782215513061749541668268478494671423742713325114941872148606581553991696282141581573380779638319877918715280435251240136086590352406727404112145703357953359376286238899061527340722256616011209201655820594402250356380003372733973387327616187483398652478541024035242690609713926955186696954805468489718103770282950d0
  if(m.eq.16)tru=0.630503946173237263505295657560687419484316217208103047750879119737058711342851877659192763501191066601982188577228262500586379030259021251047164211123005584652503444076601171694306367509196134429529516776253103930303307633895422584942517634798901062457615960522824575244252327656000461093743274793526468603824852871916766521413498376536572251925039591683519381181431312145704351598562122038533533052242581862756884420242743628060742267672215207463842163397096658569833805864256285865788069d0
  if(m.eq.32)tru=0.630473504207339806379189843197962510193081141118420178126828333519119779217268005246898075656308916946086873393397262001410555212484446423963672114690281817598779889182735230580900472592242328470004457264120286990155146506448064390469978829436786365030375680475268580627048100530589001289252950620293720898984297836797755839036805489809610349580676450908789472965991228901183202092008278874061246948493892459321177781774031467233330686503251259096722759395381792751228212765162163728318708d0
  if(m.eq.64)tru=0.630473503374386796488362088165338625359988808600159169054746716997441328971548840508887766706380139719731302865258294231669801882715049609224281367605481382589682942889020075747441483449191948683072313004358281951598012303234818904015476905081982491781473477053899423295429758958541155473364936794642857668876867306315849054817465842889811317033041580964887667713701786153216233424974723286709008987482393237633450319143260088116253143333787483540017557255302217585186907309507726430904149d0
  if(m.eq.128)tru=0.630473503374386796122040192710878904393135639979012750412245536553653956121997459635684057308921660963350457323332720649040085541797391174914889149223804811035726177862125730704169558094745080846456668418331905523709696672458886209964538837590295720117169632429702138426059061323858481321440983541931533314957025833935180816229084098252995311476596770974657314631757407942253573494293268325266772633444465268817692157141075711931602436232421502641460062433935325961698149861663106422300452d0
  if(m.eq.256)tru=0.630473503374386796122040192710878904354587078712732341573817983708970003830181326332206705697325050031561160780641257339768051805271239822919264853301390231781630022683988637073071022077390844099471939099573071733855977385570853326794060393912060962938279200444746633890279607770845068818243593284360885869895830877050816077065259676226395015715572494837496670032873293663896233868400858495009421105962180332245840734579484667306771963654166681617368088575693728706960323853235056498839156d0
  if(m.eq.512)tru=0.630473503374386796122040192710878904354587078712732341573817983708970003829958191101899541657817190994501362256504116613084047431884112434303971578077558508960323513261620519621023856418835944624875701739698847987585610110661979075138750251792562100557640869824062649551788317881009825941597948346588141535424001194580496690189908457282923429529248835670829963130164139613493822351249597446040587421013497710940743335168449424633285788417316125352856866581016019288398323457641290398134579d0
  if(m.eq.1024)tru=0.630473503374386796122040192710878904354587078712732341573817983708970003829958191101899541657817190994501362256504116613084047431884112434303971578077554684540073096172050865443368665598180980358272744760386111258149048208141490917906487963014836822604045305556726061390094145700301645427498916407885188273562314645512583127319234933825869992711015296606693152669923037568020986453295018902893350120088207565493545058798221213433349376075739795188427691651570635222481857844009406944470212d0
 elseif(a.eq.'d' .or. a.eq.'D')then
  if(m.eq.2)tru=1.d0/3
  if(m.eq.3)tru=8.d0+tpi**2/3-27.d0*0.781302412896486296867187429624092356365134336545285420222100062966886984651618218092869570832209861021042350256509035768865870552440307999260784419989574930756967213098085932160953364386339574767285839770325515898564777091242889924100249818885371308788489523887682281593269542022747136358189370747905938376851614621789917792086036135302394227603825064226268305457310112035525726489104581114952725398024966799796445479960266333365842227594600553537176562282562396301698967938757682094583043d0
  if(m.eq.4)tru=tpi**2/9.d0 -1.d0/6 - 7.d0*zeta3/2
  if(m.eq.5)tru=0.002484605762340315479950509153909749635060677642487516158707692161822137856915435753792689948724512018706872110639252051186206994499754226565626467085382841245001166822300045457032687697384896151982479613035525258515107154386381136961749224298557807628042894777027871092119811160634063125413603859840198280786401869307268109885482303788788487583058351257855236419969486914631409112736309460524093400887162838706436421861204509029973356634113727612202408834546315017113540844197840922456685d0
  if(m.eq.6)tru=0.00048914170018803477510066231535045603322055262753059988378760460832244913947351750130777133802299560444551d0
 elseif(a.eq.'e' .or. a.eq.'E')then
  if(m.eq.2)tru=6.d0-8.d0*log2
  if(m.eq.3)tru=10.d0-tpi**2/2-8.d0*log2+32.d0*log2**2
  !if(m.eq.4)tru=22.d0-24.d0*log2+176.d0*log2**2-256.d0*log2**3/3+4.d0*(tpi**2)*log2-11.d0*tpi**2/6.d0-(82.d0*12.d0/7.d0)*0.701199860176429999816513927548345827946242003865291014378825073949405620042015969275432592938778900585282842047235419660786997665892748541369564821704608427514799373387126705586195085721308121642310912280637393586509472538896550213246619069645000565993009004980705642856566060663959435388029907882636056449925250870873041513555541412129934724348326081023294168461319146078445158603840665084683055462842935104448102000145675906901520606312335807041636897619159644520465291911003465186463750d0
  if(m.eq.4)tru=22.d0-82.d0*zeta3-24.d0*log2+176.d0*log2**2-256.d0*log2**3/3+4.d0*(tpi**2)*log2-11.d0*tpi**2/6.d0
  if(m.eq.5)tru=0.00349365371172952174068806727918425156963294495514131468369898233699924152717266576695087067520893264332903998566861235384768599443866815487779823641439966119140137365416727476965866845233975094131294703225222116183255112718650890146021418d0
  if(m.eq.6)tru=0.0006878328718264094370047842736902107038148033103222727175338965396792103931668620590718645325543697533105467758387352231831720375645991880602098222503718205681784822803225117868730347366955186275157082427875765461445655735856457109451244033162090681436511005147862501959090d0
 endif 
 
 call lgwt(n,par(1),par(n+1))            ! legendre gauss quadrature on [-1,1]
 call dscal(n,0.5d0,par(n+1),1)             ! rescale to make it a measure
 forall(i=1:n)par(i)=(par(i)+1.d0)/2    ! translate [-1,1] -> [0,1]
 !forall(i=1:n)par(i)=par(i)*bnd          ! translate [-1,1] -> [-bnd,bnd]
 !call dscal(n,bnd,par(n+1),1)               !
 
 ! choose stepsize for tanh-sinh quadrature
 !h=1.d0/(n-1); val=1.d0; j=n/2
 !do while(val.gt.small_grid)
 ! h=h*(2.d0**(1.d0/m))
 ! val=(h*tpi/4)*dcosh(h*j)/dcosh( (tpi/4)*dsinh(h*j) )**2
 ! !write(*,'(2(a,e20.7))')'step size: ',h, ' value: ',val
 !end do
 !do i=0,n/2
 ! t=dtanh((tpi/4)*dsinh(h*i))
 ! w=(h*tpi/4)*dcosh(h*i)/dcosh( (tpi/4)*dsinh(h*i) )**2
 ! par( +1+n/2-i)=-t; par( +1+n/2+i)=t
 ! par(n+1+n/2-i)= w; par(n+1+n/2+i)=w
 !end do
 !forall(i=1:n)par(i)=(par(i)+1.d0)/2    ! translate [-1,1] -> [0,1]
 !forall(i=1:n)par(n+i)=par(n+i)/2       ! rescale to make it a measure
 
 !do i=1,n
 ! write(*,'(2f26.20)') par(i), par(n+i) 
 !end do
 !write(*,*)sum(par(n+1:n+n))

 ! NOTE: integrals are over [t_2 ... t_m] so it's going to be a bit confusing now
 qq%l=1;qq%m=m-1;qq%n=n;qq%r=1;call alloc(qq);
 do i=1,m-1;call dcopy(n,par(n+1),1,qq%u(i)%p,1);enddo
 call ones(qq)
 
 ! RESCALE to avoid underflow
 rescale=(a.eq.'d' .or. a.eq.'D' .or. a.eq.'e' .or. a.eq.'E') .and. (m.ge.10)
 if(rescale)then
  val=dble(n/2)
  call dscal(n,5.d0*val,par(n+1),1)
  do i=1,m-1;qq%u(i)%p=1.d0/val;end do
 else 
  val=dble(n/2)
  call dscal(n,val,par(n+1),1)
  do i=1,m-1;qq%u(i)%p=1.d0/val;end do
 end if 

 t1=timef()
 tt%l=1;tt%m=m-1;tt%n=n;tt%r=1;call alloc(tt)
  
 !distribute bonds (ranks) between procs
 own(0)=tt%l
 do p=1,nproc-1; own(p) = tt%l + int(dble(tt%m-tt%l)*dble(p)/nproc); enddo
 own(nproc) = tt%m
 !write(*,'(a,i3,a,32i4)')'[',me,']: own: ',own(0:nproc)
 
 if(tru.eq.0.d0)then
  call dtt_dmrgg(tt,dfunc_ising_discr,par,maxrank=r,accuracy=acc,own=own,pivoting=piv,neval=neval,quad=qq)
 else 
  call dtt_dmrgg(tt,dfunc_ising_discr,par,maxrank=r,accuracy=acc,own=own,pivoting=piv,neval=neval,quad=qq,tru=tru)
 endif
 t2=timef()
 tcrs=t2-t1
 if(me.eq.0)write(*,'(a,i12,a,e12.4,a)') '...with',neval,' evaluations completed in ',tcrs,' sec.'
 
 val = dtt_quad(tt,qq,own)
 if(me.eq.0) then
  if(rescale)then
   write(*,'(a,e50.40,a,i4,a)') 'computed value:', val,' / (5**',m-1,')'
  else
   write(*,'(a,e50.40)') 'computed value:', val
  end if
  if(tru.ne.0.d0)then
   write(*,'(a,e50.40)') 'analytic value:', tru
   write(*,'(a,f7.2)')   'correct digits:', -dlog(dabs(1.d0-val/tru))/dlog(10.d0)
  end if
  write(*,'(a)')'Good bye.'
 endif
 call dealloc(tt)
 call mpi_finalize(info)
 if(info.ne.0)then;write(*,*)'mpi: finalize fail: ',info;stop;endif
end program

double precision function dfunc_ising_discr(m,ind,n,par) result(f)
 implicit none
 integer,intent(in) :: m
 integer,intent(in) :: ind(m),n(m)
 double precision,intent(inout),optional :: par(*)
 integer :: nodes,weights,i,j,id
 double precision :: uij,a,b,v,w,wk,vk
 id=int(par(2*n(1)+1))
 nodes=0       ! t2 t3 ... tm
 weights=n(1)  ! w2 w3 ... wm
 if(id.eq.2 .or. id.eq.3)then
  a=1.d0
  do i=0,m
   uij=1.d0
   do j=i+1,m
    uij=uij*par(nodes+ind(j))
    a = a * (( uij-1.d0 ) / ( uij+1.d0 ))**2
   end do
  end do
 end if
 if(id.eq.1 .or. id.eq.2)then
  v=1.d0; w=1.d0; vk=1.d0; wk=1.d0
  do i=1,m
   vk=vk*par(nodes+ind(m-i+1))
   wk=wk*par(nodes+ind(i))
   v=v+vk
   w=w+wk
  end do
  b=1.d0/(v*w)
 end if 
 select case(id)
 case(1);f=2*b
 case(2);f=2*a*b
 case(3);f=2*a
 case default
  write(*,*)'unknown id: ',id;stop
 end select 
  
 ! apply weights
 do i=1,m
  f=f*par(weights+ind(i))
 end do
end function