include "globals.mzn";

% Constants
enum WEEKDAYS = {Mon, Tue, Wed, Thu, Fri, Sat, Sun};
enum DUTIES = {N, A, P, O, D};
enum TYPES0 = {LYG, BFY, DNY, BEE, NIGHT, OFFICE, HOME};
enum RULES = {WardReqDuty,            % ward request duty constraint
              ContractDayOff,         % contract O + public holiday O entitlement constraint
              WeekendOff,             % # of weekend O constraint
              DailyA1Duty,            % daily A1 duty constraint (mandatory)
              MinWardStaffReq,        % daily ward requirement constraint (mandatory)
              NormalDutyStateDiagram, % normal AN constraint
              NormalNightFrequency,   % at most 1 N for CN days constraint (mandatory)
              CallNightDuty,          % call night then O then not A constraint (mandatory)
              NormalOffFrequency,     % at least 1 O for NW days constraint (mandatory)
              DayConsecutiveAL,       % ward requested consecutive 3Os for day-teachers (mandatory)
              NightConsecutiveAL,     % ward requested consecutive 4Os for night-teachers (mandatory)
              PublicHolidayOff,       % # of public holiday O constraint
              WardDayDuty             % ward requested D duty constraint
              };
enum HEURISTICS = { NonHomeClassAssignment,      % non-home class assignment
                    DayStaffPA,                  % PA for day-teachers
                    DayStaffNOA,                 % NOA for day-teachers
                    NightStaff1N1O,              % 1N1O for night-teachers
                    NightStaff3N1O,              % 3N1O for night-teachers
                    Class2A1P,                   % 2A1P for classes
                    UnevenDayUnfavor,            % uneven unfavorable duty for day-teachers
                    UnevenNightUnfavor,          % uneven unfavorable duty for night-teachers
                    UnevenFavorOs                % uneven favorable Os for all teachers
                    };
enum MINS = { shift, ladybug, butterfly, dragonfly, bee, night };
enum UNFAVORS = { early, pc, day2night, pa, noa, night1n1o, night3n1o };
array[DUTIES] of string: lowercase = ["n", "a", "p", "o", "d"];
array[CLASSES] of string: shortform = ["L", "F", "D", "B", "N"];

% Parameters
int: nRosterDays; % number of days in the roster
int: MW;          % maximum number of consecutive shifts
int: nLADYBUG;    % number of staffs in LADYBUG class
int: nBUTTERFLY;  % number of staffs in BUTTERFLY class
int: nDRAGONFLY;  % number of staffs in DRAGONFLY class
int: nBEE;        % number of staffs in BEE class
int: nNIGHT;      % number of NIGHT staffs
int: nCOD;        % minimum number of Os in roster for day teachers
int: nCON;        % minimum number of Os in roster for night teachersws
WEEKDAYS: MONTH_START;
array[int, int] of int: min_ward;
array[int, int] of int: max_ward;
array[int] of ReqDuties: WARD_REQ_DUTIES;
set of DAYS: call_req_duties;
array[RULES] of bool: active_constraints;
array[HEURISTICS] of int: heuristics_weights;
set of DAYS: public_holidays;

% Tuples/Records
type ClassMins = tuple(CLASSES, MINS);
type ReqDuties = record(STAFFS: staff, DAYS: day, DUTIES: duty);
type Assignment = record(DUTIES: duty, TYPES0: place);

% Derived Parameters
enum STAFFS = LYG(1..nLADYBUG) ++ BFY(1..nBUTTERFLY) ++ DNY(1..nDRAGONFLY) ++ BEE(1..nBEE) ++ NGT(1..nNIGHT);
int: nStaffs = card(STAFFS);
int: nWeekends = card(weekends);
int: nDuties = card(DUTIES);
int: nClasses = card(CLASSES);
int: nPHs = card(public_holidays);
set of TYPES0: CLASSES = {LYG, BFY, DNY, BEE, NIGHT};
array[CLASSES] of int: nClassStaffs = [nLADYBUG, nBUTTERFLY, nDRAGONFLY, nBEE, nNIGHT];
array[CLASSES] of ClassMins: CLASS_MINS = [(LYG, ladybug), (BFY, butterfly), (DNY, dragonfly), (BEE, bee), (NIGHT, night)];
set of WEEKDAYS: WEEKEND = {Sat, Sun};
set of DUTIES: SHIFTS = {N, A, P};
set of DUTIES: OFF = {O};
set of UNFAVORS: DAY_UNFAVORS = {early, pc, day2night, pa, noa};
set of UNFAVORS: NIGHT_UNFAVORS = {night1n1o, night3n1o};
array[int] of Assignment: allAssignments = [(duty: i, place: j) | i in SHIFTS where i != N, j in CLASSES where j != NIGHT] ++ 
                                           [(duty: N, place: NIGHT), (duty: O, place: HOME), (duty: D, place: OFFICE)];
set of int: ASSIGNMENTS0 = 1..length(allAssignments);
set of ASSIGNMENTS0: ASSIGNMENTS = 1..9;    % 4 classes for A/P + 1 night

% Derived Parameters (for cross-month calendar generation)
int: nPrevMthDays = 7;
int: nNextMthDays = 2;
enum DAYS = V(1..nPrevMthDays) ++ C(1..nRosterDays) ++ X(1..nNextMthDays);
array[DAYS] of WEEKDAYS: DAY_WEEKDAYS = [weekday(i) | i in DAYS];
set of DAYS: weekends = array2set([i | i in DAYS where DAY_WEEKDAYS[i] in WEEKEND]);
set of DAYS: favor_Os = weekends union public_holidays;
int: nDays = card(DAYS);

% Derived Parameters
array[CLASSES] of set of STAFFS: CLASS_STAFFS = [LYG(1..nLADYBUG), BFY(1..nBUTTERFLY), DNY(1..nDRAGONFLY), BEE(1..nBEE), NGT(1..nNIGHT)];
array[int] of int: MIN_WARD = convert(min_ward);
array[int] of int: MAX_WARD = convert(max_ward);

% Function to get mask value for specific staff/day
function opt DUTIES: get_special_mask(STAFFS: s, DAYS: d) =
    if (staff: s, day: d, duty: O) in WARD_REQ_DUTIES then D else <> endif;

% Create the mask array
array[STAFFS, DAYS] of opt DUTIES: special_mask = 
    array2d(STAFFS, DAYS, [get_special_mask(s,d) | s in STAFFS, d in DAYS]);

% Function to apply mask
function array[DAYS] of var DUTIES: apply_special_mask(STAFFS: s, array[DAYS] of var DUTIES: staff_roster) =
    array1d(DAYS, [if occurs(special_mask[s,d]) then deopt(special_mask[s,d]) else staff_roster[d] endif
                  | d in DAYS ]);

% Decision Variables
array[STAFFS, DAYS] of var ASSIGNMENTS0: roster;
array[DAYS, ASSIGNMENTS0] of var set of STAFFS: ward;
array[DAYS] of var opt STAFFS: a1;
array[DAYS] of var opt STAFFS: call;
array[STAFFS, DUTIES] of var int: staff_duty_counts;
array[STAFFS, UNFAVORS] of var int: staff_unfavor_counts;
array[STAFFS] of var int: staff_favor_O_counts;

% Channel constraints for roster/ward
constraint forall(i in DAYS) (
    partition_set(row(ward,i), STAFFS)
);
constraint forall(i in DAYS) (
    int_set_channel(col(roster,i), row(ward,i))
);
constraint forall(i in STAFFS) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in global_cardinality([assignment_to_duty(temp[j]) | j in C(1..nRosterDays)], DUTIES, row(staff_duty_counts,i))
);
constraint global_cardinality(a1, STAFFS, col(staff_unfavor_counts,early));
constraint global_cardinality(call, STAFFS, col(staff_unfavor_counts,pc));
constraint forall(i in STAFFS) (
    staff_unfavor_counts[i,day2night] = if i in CLASS_STAFFS[NIGHT] then 0 else staff_duty_counts[i,N] endif
);
type day_unfavor_pat = record(DAY_UNFAVORS: unfavor, array[int] of DUTIES: pat);
array[int] of day_unfavor_pat: day_criteria = [(unfavor: pa, pat: [P, A]), 
                                               (unfavor: noa, pat: [N, O, A])];
constraint forall(i in STAFFS) (
    forall(j in day_criteria) (
        staff_unfavor_counts[i,j.unfavor] = if not (i in CLASS_STAFFS[NIGHT]) 
        then count_subseq([assignment_to_duty(roster[i,k]) | k in DAYS], j.pat) else 0 endif)
);
type night_unfavor_pat = record(NIGHT_UNFAVORS: unfavor, array[int] of DUTIES: pat);
array[int] of night_unfavor_pat: night_criteria = [(unfavor: night1n1o, pat: [O, N, O, N]), 
                                                   (unfavor: night3n1o, pat: [O, N, N, N, O, N])];
constraint forall(i in STAFFS) (
    forall(j in night_criteria) (
        staff_unfavor_counts[i,j.unfavor] = if i in CLASS_STAFFS[NIGHT] 
        then count_subseq([assignment_to_duty(roster[i,k]) | k in DAYS], j.pat) else 0 endif)
);
constraint forall(i in STAFFS) (
    global_cardinality([assignment_to_duty(roster[i,j]) | j in favor_Os], OFF, [staff_favor_O_counts[i]])
);

% Rule feature toggle constraints
constraint active_constraints[WardReqDuty] -> rules1();
constraint active_constraints[ContractDayOff] -> rules2();
constraint active_constraints[WeekendOff] -> rules3();
constraint active_constraints[DailyA1Duty] -> rules4();
constraint active_constraints[MinWardStaffReq] -> rules5();
constraint active_constraints[NormalDutyStateDiagram] -> rules6();
constraint active_constraints[NormalNightFrequency] -> rules7();
constraint active_constraints[CallNightDuty] -> rules8();
constraint active_constraints[NormalOffFrequency] -> rules9();
constraint active_constraints[DayConsecutiveAL] -> rules10();
constraint active_constraints[NightConsecutiveAL] -> rules11();
constraint active_constraints[PublicHolidayOff] -> rules12();
constraint active_constraints[WardDayDuty] -> rules13();

% Rule 1: constraint of matching roster with WARD_REQ_DUTIES
predicate rules1 = forall(i in WARD_REQ_DUTIES) (
    assignment_to_duty(roster[i.staff,i.day]) == i.duty
);

% Rule 2: constraint of # of Os (contract + public holidays) for every nurse in a month
int: min_O_count_day = nCOD + nPHs;
int: min_O_count_night = nCON + nPHs;
int: max_O_count = nDays;
predicate rules2 = (forall(i in STAFFS) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in (not (i in CLASS_STAFFS[NIGHT]) -> global_cardinality([assignment_to_duty(temp[j]) | j in C(1..nRosterDays)], OFF, [min_O_count_day], [max_O_count])) /\
    (i in CLASS_STAFFS[NIGHT] -> global_cardinality([assignment_to_duty(temp[j]) | j in C(1..nRosterDays)], OFF, [min_O_count_night], [max_O_count]))
));

% Rule 3: constraint of min # of contract Os for every teacher
int: min_weekend_O = round(card(DAYS) div 15);
predicate rules3 = (forall(i in STAFFS) (
    global_cardinality([assignment_to_duty(roster[i,j]) | j in C(1..nRosterDays)], OFF, [min_weekend_O], [nWeekends])
));

% Rule 4: constraint of daily A1 duty constraint
predicate rules4 = (forall(i in DAYS) (
    (i in C(1..nRosterDays) -> (occurs(a1[i]) /\ assignment_to_duty(roster[deopt(a1[i]),i]) == A)) /\
    (not (i in C(1..nRosterDays)) -> absent(a1[i]))
));

% Rule 5: constraint of min # of staffs of all types in every N/A/P duties
predicate rules5 = (forall(i in C(1..nRosterDays)) (
    global_cardinality(col(roster,i), ASSIGNMENTS, MIN_WARD, MAX_WARD)
));

% Rule 6: constraint of normal N requirement
int: Q1 = 2;
int: q0 = 1;
set of int: STATE1 = 1..Q1;
array[STATE1, DUTIES] of int: t1 = 
  [| 2, 1, 1, 1, 1      % state 1 (allow N at the 1st day)
   | 0, 0, 0, 1, 0 |];  % state 2 (can only have O)
predicate rules6 = (forall(i in STAFFS where not (i in CLASS_STAFFS[NIGHT])) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in regular([assignment_to_duty(temp[j]) | j in DAYS], Q1, nDuties, t1, q0, STATE1)
));

% Rule 7: constraint of 2Os for consecutive 4Ns in a row
int: Q2 = 6;
set of int: STATE2 = 1..Q2;
array[STATE2, DUTIES] of int: t2 = 
  [| 2, 0, 0, 1, 0      % state 1
   | 3, 0, 0, 1, 0      % state 2
   | 4, 0, 0, 1, 0      % state 3 
   | 5, 0, 0, 1, 0      % state 4
   | 0, 0, 0, 6, 0      % state 5 (cannot N again)
   | 0, 0, 0, 1, 0 |];  % state 6 (cannot N again)
predicate rules7 = (forall(i in CLASS_STAFFS[NIGHT]) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in regular([assignment_to_duty(temp[j]) | j in DAYS], Q2, nDuties, t2, q0, STATE2)
));

% Rule 8: constraint of call night then O and then cannot A
predicate rules8 = (forall(i in DAYS) (
     (not (i in call_req_duties) -> absent(call[i])) /\
     ((i in call_req_duties /\ enum_next(i) in DAYS /\ enum_next(enum_next(i)) in DAYS) -> (occurs(call[i]) /\ 
      let { 
          var STAFFS: staff = deopt(call[i])
      } in assignment_to_duty(roster[staff,i]) == P /\ assignment_to_duty(roster[staff,enum_next(i)]) == O /\ assignment_to_duty(roster[staff,enum_next(enum_next(i))]) != A))
));

% Rule 9: constraint of at least 1 O for every nurse in every consecutive MW days
int: Q4 = MW;
set of int: STATE4 = 1..Q4;
array[STATE4,DUTIES] of int: t4 = array2d(STATE4, DUTIES, [if j == O then q0 else i endif | i in 2..MW, j in DUTIES] ++
                                                          [0,0,0,q0,0]);
predicate rules9 = (forall(i in STAFFS where not (i in CLASS_STAFFS[NIGHT])) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in regular([assignment_to_duty(temp[j]) | j in DAYS], Q4, nDuties, t4, q0, STATE4)
));

% Rule 10: constraint of no consecutive 3Os for day-teachers if not ward-requested
int: Q5 = 5;
set of int: STATE5 = 1..Q5;
enum WORKPOAL = {W, PO, AL};
int: nWORKPOAL = card(WORKPOAL);
array[STATE5,WORKPOAL] of int: t5 = 
  [| 1, 2, 4      % state 1
   | 1, 3, 3      % state 2
   | 1, 0, 0      % state 3 (cannot PO and AL again)
   | 1, 3, 5      % state 4
   | 1, 0, 5 |];  % state 5 (cannot PO again)
function array[DAYS] of var WORKPOAL: convert_wpoal(STAFFS: staff, array[DAYS] of var ASSIGNMENTS0: asgmts) = 
    array1d(DAYS,[if not (assignment_to_duty(asgmts[j]) in OFF) then W 
                  elseif (staff: staff, day: j, duty: O) in WARD_REQ_DUTIES then AL else PO endif | j in DAYS]);
predicate rules10 = (forall(i in STAFFS where not (i in CLASS_STAFFS[NIGHT])) (
    regular(convert_wpoal(i,row(roster,i)), Q5, nWORKPOAL, t5, q0, STATE5)
));

% Rule 11: constraint of no consecutive 4Os for night-teachers if not ward-requested
int: Q6 = 7;
set of int: STATE6 = 1..Q6;
array[STATE6,WORKPOAL] of int: t6 = 
  [| 1, 2, 5      % state 1
   | 1, 3, 3      % state 2
   | 1, 4, 4      % state 3
   | 1, 0, 0      % state 4 (cannot PO and AL again)
   | 1, 3, 6      % state 5 
   | 1, 4, 7      % state 6 
   | 1, 0, 7 |];  % state 7 (cannot PO again)
predicate rules11 = (forall(i in CLASS_STAFFS[NIGHT]) (
    regular(convert_wpoal(i,row(roster,i)), Q6, nWORKPOAL, t6, q0, STATE6)
));

% Rule 12: constraint of >=1 public holiday Os for every nurse in a month if # of public holidays >= 3
int: min_ph_O = round((nPHs-1)/3);
predicate rules12 = (forall(i in STAFFS) (
    global_cardinality([assignment_to_duty(roster[i,j]) | j in public_holidays], OFF, [min_ph_O], [nPHs])
));

% Rule 13: constraint of D duty must appear in WARD_REQ_DUTIES
predicate rules13 = forall(i in STAFFS, j in DAYS) (
    assignment_to_duty(roster[i,j]) == D -> has_element((staff: i, day: j, duty: D), WARD_REQ_DUTIES)
);

% heuristics score array
array[HEURISTICS] of var int: scores = [score1(), score2(), score3(), score4(), score5(), score6(), score7(), score8(), score9()];

% Score 1: non-home class assignment (including N for day-teachers)
function var int: score1() = sum(i in STAFFS, j in DAYS where assignment_to_duty(roster[i,j]) in SHIFTS) (not home_class_assigned(i,roster[i,j]));  

% Score 2: PA for day-teachers
function var int: score2() = sum(i in STAFFS) (staff_unfavor_counts[i,pa]);

% Score 3: NOA for day-teachers
function var int: score3() = sum(i in STAFFS) (staff_unfavor_counts[i,noa]);

% Score 4: 1N1O for night-teachers
function var int: score4() = sum(i in STAFFS) (staff_unfavor_counts[i,night1n1o]);

% Score 5: 3N1O for night-teachers
function var int: score5() = sum(i in STAFFS) (staff_unfavor_counts[i,night3n1o]);

% Score 6: # of A > # of P in every day class
function var int: score6() = sum(i in C(1..nRosterDays), j in CLASSES where j != NIGHT) (
                              card(ward[i,arg_val(allAssignments,(duty: A, place: j))]) > 
                              card(ward[i,arg_val(allAssignments,(duty: P, place: j))]));

% Score 7: uneven unfavorable duties among day teachers
function var int: score7() = sum(i in DAY_UNFAVORS) (max_diff([col(staff_unfavor_counts,i)[j] | j in STAFFS where not (j in CLASS_STAFFS[NIGHT])])) +
                             max_diff([sum(j in DAY_UNFAVORS) (row(staff_unfavor_counts,i)[j]) | i in STAFFS where not (i in CLASS_STAFFS[NIGHT])]);

% Score 8: uneven unfavorable duties among night teachers
function var int: score8() = sum(i in NIGHT_UNFAVORS) (max_diff([col(staff_unfavor_counts,i)[j] | j in CLASS_STAFFS[NIGHT]])) +
                             max_diff([sum(j in NIGHT_UNFAVORS) (row(staff_unfavor_counts,i)[j]) | i in CLASS_STAFFS[NIGHT]]);

% Score 9: uneven weekend+PH Os among all teachers
function var int: score9() = max_diff(staff_favor_O_counts);

% Objective function
solve :: int_search(roster, first_fail, indomain_min) minimize sum(i in HEURISTICS) (heuristics_weights[i] * scores[i]);

% Helper functions
function var DUTIES: assignment_to_duty(var ASSIGNMENTS0: index) = allAssignments[index].duty;
function var CLASSES: assignment_to_class(var ASSIGNMENTS0: index) = to_enum(CLASSES, allAssignments[index].place);
function var bool: home_class_assigned(STAFFS: staff, var ASSIGNMENTS0: index) = staff in CLASS_STAFFS[assignment_to_class(index)];

function WEEKDAYS: weekday(DAYS: day) = 
    let {
        int: temp = (enum2int(day) - enum2int(C(1)) + enum2int(MONTH_START)) mod 7
    } in 
    to_enum(WEEKDAYS, if temp <= 0 then temp + 7 else temp endif);

function string: format_duty(STAFFS: staff, DAYS: day) = 
    let {
        DUTIES: duty = fix(assignment_to_duty(roster[staff,day]))
    } in
    if fix(call[day]) == staff then "C" elseif fix(a1[day]) == staff then "&" else format(duty) endif;
    /*if temp[duty] then format(duty) elseif xorall(temp) then lowercase[duty] else " " endif;*/

function string: format_class(STAFFS: staff, DAYS: day) = 
    let {
        ASSIGNMENTS0: assignment = fix(roster[staff,day])
    } in if assignment in ASSIGNMENTS then shortform[fix(assignment_to_class(assignment))] else " " endif;

function string: format_manpower(array[STAFFS] of ASSIGNMENTS0: assignments, CLASSES: class) = 
    let {
        array[STAFFS] of SHIFTS: temp = [if fix(assignments[i]) in ASSIGNMENTS then 
                                            if fix(assignment_to_class(assignments[i])) == class 
                                            then fix(assignment_to_duty(assignments[i]))
                                            else N endif
                                         else N endif | i in STAFFS]
    } in join("", [format(count([temp[j] == i | j in STAFFS])) ++ format(i) | i in {A, P}]);

function array[int] of int: convert(array[int, int] of int: input) = 
    let {
        array[SHIFTS, MINS] of int: temp = array2d(SHIFTS, MINS, input)
    } in [temp[i,j.2] | i in SHIFTS where i != N, j in CLASS_MINS where j.1 != NIGHT] ++ [temp[N,night]];

function var int: max_diff(array[int] of var int: input) = max(input) - min(input);

function var int: count_subseq(array[int] of var DUTIES: main, array[int] of DUTIES: pat) =
    let { int: m = length(main),
          int: n = length(pat)
    } in if n > m then 0 else sum(i in 1..m-n+1) (forall(j in 1..n)(main[i+j-1] == pat[j])) endif;

% Verify data input and derived parameters
%output ["Whole calendar: "] ++ [show(i) ++ " " | i in DAYS] ++ ["\n"];
%output ["Whole calendar: "] ++ [show(DAY_WEEKDAYS)] ++ ["\n"];
%output ["Available weekends: "] ++ [show(weekends)] ++ ["\n"];
%output ["Available teachers: "] ++ [show(card(CLASS_STAFFS[i])) ++ " " | i in CLASSES] ++ ["\n"];
%output ["allAssignments: \n"] ++ [show(allAssignments)] ++ ["\n"];
%output ["allAssignments in ASSIGNMENTS: \n"] ++ [show([allAssignments[i] | i in ASSIGNMENTS])] ++ ["\n"];
%output ["MIN_WARD: "] ++ [show(MIN_WARD)] ++ ["\n"];
%output ["MAX_WARD: "] ++ [show(MAX_WARD)] ++ ["\n"];

% Result printing
output["\t" ++ join(" ",[if i in {C(1),X(1)} then "1" else " " endif | i in DAYS]) ++ "\n"];
output["\t" ++ join(" ",[if i in weekends then "S" else " " endif | i in DAYS]) ++ "\t" ++ join("\t",[show(i) | i in DUTIES]) ++ "\n"];
output[show(i) ++ "\t" ++ join(" ",[format_duty(i,j) | j in DAYS]) ++ "\t" ++ join("\t",[show(fix(staff_duty_counts[i,j])) | j in DUTIES]) ++ "\n" | i in STAFFS];
output["\t" ++ join(" ",[if i in {C(1),X(1)} then "1" else " " endif | i in DAYS]) ++ "\n"];
output["\t" ++ join(" ",[if i in weekends then "S" else " " endif | i in DAYS]) ++ "\n"];
output[show(i) ++ "\t" ++ join(" ",[format_class(i,j) | j in DAYS]) ++ "\n" | i in STAFFS];
output["# of non-home(s) = " ++ show(fix(scores[NonHomeClassAssignment])) ++
        "\t# of PAs= " ++ show(fix(scores[DayStaffPA])) ++
        "\t# of NOAs= " ++ show(fix(scores[DayStaffNOA])) ++
        "\t# of ONONs= " ++ show(fix(scores[NightStaff1N1O])) ++ 
        "\t# of ONNNONs= " ++ show(fix(scores[NightStaff3N1O])) ++ "\n"];
output["# of 2A1Ps= " ++ show(fix(scores[Class2A1P])) ++ "\n"];
output["Total # of max day unfavor diffs= " ++ show(fix(scores[UnevenDayUnfavor])) ++ 
        "\tTotal # of max night unfavor diffs= " ++ show(fix(scores[UnevenNightUnfavor])) ++
        "\tTotal # of max favor O diffs= " ++ show(fix(scores[UnevenFavorOs])) ++ "\n"];
output["\t" ++ join("\t",[show(i) | i in CLASSES where i != NIGHT]) ++ "\n"];
output[show(i) ++ "\t" ++ join("\t",[format_manpower(fix(col(roster,i)),j) | j in CLASSES where j != NIGHT]) ++ "\n" | i in DAYS];
output[show2d(fix(staff_unfavor_counts))];