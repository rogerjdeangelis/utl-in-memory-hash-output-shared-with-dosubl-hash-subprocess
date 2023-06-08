%let pgm=utl-in-memory-hash-output-shared-with-dosubl-hash-subprocess;

The dosubl subprocess could be any process, ie sql, datastep, procs

This is purely academic.

github
https://tinyurl.com/nhjs26dc
https://github.com/rogerjdeangelis/utl-in-memory-hash-output-shared-with-dosubl-hash-subprocess

DOSUBL does seem to share and address space wit the mainline process.

Problem
  Create a sorted cumulative sum by subject.

It seems solid, I always run batch, but beware

     1. Making sure use are accessing the correct memory locations or some cached memory.
        Win 10 does not clear memory between sas processes.
     2. SAS macro variables may not have been reset, set and may be from a previous process
     3. You may be accessing old SAS datasets because process failed to create new ones.
     4. Poking into memory can be disasterous.

SOAPBOX ON

  SAS needs to improve the execution speed of DOSUBL. Make an executable?
  Also SAS could set up common and eqivalence shared blocks of storage (for arrays and variables)
  I have posted COMMONC and COMMONN macros to use with dosubl
     See FORTRAN COMMON and EQUIVALENCE STATEMENTS

     Here Variable i is shared with dosubl

        https://github.com/rogerjdeangelis/utl_dosubl_subroutine_interfaces
        data _null_;
          %commonn(i);
          do i= 1 to 4;
            rc=dosubl('
              data _null_;
                 %commonn(i,action=GET);
                 sqrt=int(sqrt(i));
                 if sqrt*sqrt=i then call symputx("Answer"," isPerfectSquare","G");
                 else call symputx("Answer","NotPerfectSquare","G");
              run;quit;
            ');
            answer=symget('answer');
            put i= answer=;
          end;
        run;quit;
   After doing this SAS could deprecate FCMP? Less is More.
   With 128bit floats SAS could deprecate DS2, FEDSQL .....
   IBM is working with Intel to add a core that supports 128bit floats?
   Not all cores need this, IBM developed 128bit engine for its muti-processors back in the 80's
   and SAS proc matrix used it.

SOAPBOX OFF


Related

https://github.com/rogerjdeangelis/utl_dosubl_subroutine_interfaces
https://github.com/rogerjdeangelis/utl-twelve-interfaces-for-dosubl

Paul Dorfman's SESUG paper
https://tinyurl.com/3ydfs3n4
https://www.lexjansen.com/sesug/2018/SESUG2018_Paper-288_Final_PDF.pdf

GitHub
https://tinyurl.com/y4jafbhs
https://github.com/rogerjdeangelis/utl-using-a-hash-to-compute-cumulative-sum-without-sorting

SAS Forum
https://tinyurl.com/y4jafbhs
https://communities.sas.com/t5/SAS-Programming/Cumulative-Sum-without-sorting/m-p/692952


/*                   _
(_)_ __  _ __  _   _| |_
| | `_ \| `_ \| | | | __|
| | | | | |_) | |_| | |_
|_|_| |_| .__/ \__,_|\__|
        |_|
*/

data have;
input Name $ Amount;
cards;
Egar 3
Gigi 4
Dave 3
Carl 2
Fred 6
Fred 4
Fred 4
;;;;
run;quit;

/**************************************************************************************************************************/
/*                                       |                                                                                */
/* HAVE total obs=7 08JUN2023:10:19:09   | RULES (75% of my statements are not needed everthing can be done with arrays)  */
/*                                       |                                                                                */
/*  Obs    NAME    AMOUNT                | 1. FIRST HASH: CREATE CUMULATIVE SUMS                                          */
/*                                       |                                                                                */
/*   1     Egar       3                  | WANTCUM total obs=7 08JUN2023:10:46:42                                         */
/*   2     Gigi       4                  |                                                                                */
/*   3     Dave       3                  |   NAMES    AMOUNTS                                                             */
/*   4     Carl       2                  |                                                                                */
/*   5     Fred       6                  |   Egar         3    ===> Not in sorted order                                   */
/*   6     Fred       4                  |   Gigi         4                                                               */
/*   7     Fred       4                  |   Dave         3                                                               */
/*                                       |   Carl         2                                                               */
/* OUTPUT  Sorted Cumlative              |                                                                                */
/*                                       |   Fred         6    ==>6                                                       */
/*  WANTFIN total obs=7                  |   Fred        10    ==>6+4                                                     */
/*                                       |   Fred        14    ==>6+4+10                                                  */
/*   NAME    AMOUNT                      |                                                                                */
/*                                       | 2. SECOND HASH: PASS ARRAY FROM MAINLINE HASH OUTUT TO DOSUBL HASH             */
/*   Carl       2                        |                                                                                */
/*   Dave       3                        |  WANTAFT total obs=7 08JUN2023:10:53:30                                        */
/*   Egar       3                        |                                                                                */
/*   Gigi       4                        |   NAME    AMOUNT                                                               */
/*   Fred       6 ==>6                   |                                                                                */
/*   Fred      10 ==>6+4                 |   Carl       2   => Array sorted by name amount                                */
/*   Fred      14 ==>6+4+10              |   Dave       3                                                                 */
/*                                       |   Egar       3                                                                 */
/*                                       |   Gigi       4                                                                 */
/*                                       |   Fred       6                                                                 */
/*                                       |   Fred      10                                                                 */
/*                                       |   Fred      14                                                                 */
/*                                       |                                                                                */
/*                                       | 3. FINALALLY:PASS SORTED ARRAY FROM SECOND HASH BACK TO MAINLINE               */
/*                                       |                                                                                */
/*                                       |  WANTFIN total obs=7 08JUN2023:10:58:14                                        */
/*                                       |                                                                                */
/*                                       |   NAME    AMOUNT                                                               */
/*                                       |                                                                                */
/*                                       |   Carl       2                                                                 */
/*                                       |   Dave       3                                                                 */
/*                                       |   Egar       3                                                                 */
/*                                       |   Gigi       4                                                                 */
/*                                       |   Fred       6                                                                 */
/*                                       |   Fred      10                                                                 */
/*                                       |   Fred      14                                                                 */
/*                                       |                                                                                */
/**************************************************************************************************************************/

title;
proc datasets lib=work nolist mt=data mt=cat nodetails;
 delete  sasmac1 sasmac2 want:;;
run;quit;


%symdel adrQue adrAns / nowarn;

data wantFin (keep=name amount) wantCum(keep=names amounts);

  array que[7] $4 _temporary_;
  array ans[7] _temporary_;

  adrQue=put(addrlong(que[1]),$hex16.);
  adrAns=put(addrlong(ans[1]),$hex16.);

  call symputx('adrQue',adrQue);
  call symputx('adrAns',adrAns);

  if _n_=1 then do;
    dcl hash h(suminc:'amount');
    h.definekey('name');
    h.definedone();
  end;
  do _i_=1 by 1 until ( eof );
    set have end=eof;
    h.ref();
    h.sum(sum:Cumulative_Sum);
    que[_i_]=name;
    ans[_i_]=Cumulative_Sum;
  end;
  do i = lbound (que) to hbound (que) ;
     names   = que[i];
     amounts = ans[i];
     output wantCum;
  end;

  rc=dosubl('

    data  wantAft (drop=_kn _kc) ;

       array KN [7] _temporary_  (7*0);
       array KC [7] $4 _temporary_ (7*"NULL");

       dcl hash s (multidata:"Y", ordered:"A") ;
       s.defineKey ("_KN") ;
       s.defineKey ("_KC") ;

       /*----  No DEFINEDATA call,_KN/_KC are added to data portion by default  ----*/
       s.defineDone () ;
       dcl hiter is ("s") ;
       do i = lbound (KN) to hbound (KN) ;
         _KN = input(peekclong (ptrlongadd ("&adrAns"x,(i-1)*8),8),rb8.); ;
         _KC  =      peekclong (ptrlongadd ("&adrQue"x,(i-1)*4),4);
          s.REF() ;
       end ;
       do i = lbound (KN) to hbound (KN) ;
         if i <= hbound (KN) - s.NUM_ITEMS then do ;
           KN[i] = . ;
           KC[i] = . ;
         end;
         else do ;
          is.NEXT() ;
           KN[i] = _KN ;
           KC[i] = _KC ;
         end ;
       end ;
       /*----  After sort                                                       ----*/
       do i = lbound (KN) to hbound (KN) ;
         put "Sorted: KN: " KN[i] +10  "KC: " KC[i] ;
         call  pokelong(KN[i],ptrlongadd ("&adrAns"x,(i-1)*8),8);
         call  pokelong(KC[i],ptrlongadd ("&adrQue"x,(i-1)*4),4);
         name   = kc[i];
         amount = kn[i];
         keep name amount _KN _KC;
         output wantAft;
       end;
       stop;
       run;quit;
       ');
       /*----     Back to Mainline                                              ----*/
       do i = lbound (Que) to hbound (Que) ;
         put "Sorted: Que: " Que[i] +10  "Ans: " Ans[i] ;
         name=que[i];
         amount=ans[i];
         output wantFin;
         keep name amount names amounts;
       end;
   stop;
run;quit;

/*              _
  ___ _ __   __| |
 / _ \ `_ \ / _` |
|  __/ | | | (_| |
 \___|_| |_|\__,_|

*/
