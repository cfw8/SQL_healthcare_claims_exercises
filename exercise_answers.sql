-- Suppose we want to study members that are new users of the drug lisinopril.
-- Count the number of Medicare members that meet the following criteria:
-- 1. Were continuously enrolled in all of 2017 and 2018 in a MAPD plan
-- 2. Had at least one filled prescription for lisinopril during 2018
-- 3. Did not have a filled prescription for lisinopril during 2017

select count(distinct a.mem_id) as member_count
from
--people on lisinopril in 2018
  (select distinct mem_id
  from `df.pharmacy_claim`
  --look up ndc code to get more accurate
  where gnrc_nm like '%lisinopril%'
  and full_dt between '2018-01-01' and '2018-12-31'
  ) as a
-- medicare population
inner join
  (
  --filter to continuously enrolled mapd members in 2017-2018
  select distinct(mem_id), count(year_mo) as month_cnt
  from df.member
  -- include members which we provide prescription coverage for
  where mapdflag = 1
  -- only looking at continuously enrolled members 2017-2018
  and year_mo between 201701 and 201812
  group by mem_id
  ) as b
on a.mem_id = b.mem_id
-- people NOT on lisinopril 2017
left join
  (
  select distinct mem_id
  from `df.pharmacy_claim`
  where gnrc_nm like '%lisinopril%'
  and full_dt between '2017-01-01' and '2017-12-31'
  ) as c
on a.mem_id = c.mem_id
-- continuously enrolled 2017-2018
where month_cnt = 24
-- not taking lisinopril in 2017
and c.mem_id IS NULL
-- member count: 76,358

-- Using the population specified in exercise #1, how many of these members also had 6 months of
-- continuous enrollment after the first month they filled a prescription for lisinopril in 2018.
-- (Note: These 6 months can extend into 2019.)
-- grab people from first problem
with table1 as (
select distinct a.mem_id
from
--people on lisinopril
(select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2018-01-01' and '2018-12-31'
) as a
inner join
(
--filter to continuously enrolled mapd members in 2017-2018
select distinct(mem_id), count(year_mo) as month_cnt
from df.member_detail
-- include members which we provide prescription coverage for
where mapdflag = 1
-- only looking at continuously enrolled members 2017-2018
and year_mo between 201701 and 201812
group by mem_id

) as b
on a.mem_id = b.mem_id
left join
(
select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2017-01-01' and '2017-12-31'
) as c
on a.mem_id = c.mem_id
-- continuously enrolled 2017-2018
where month_cnt = 24
and c.mem_id IS NULL
)
-- get the first date people took lisinopril
-- 76358 people
,table2 as (
select distinct one.mem_id, first_dt
from (
(select mem_id
from table1) as one
join (
select mem_id, min(full_dt) as first_dt
from `df.pharmacy_claim`
where year_mo between 201801 and 201812
and gnrc_nm like '%lisinopril%'
group by mem_id
) as two
on one.mem_id = two.mem_id
)
)

-- make sure people are continuously enrolled for the 6 months following first drug fill
,table3 as (
select distinct a.mem_id, first_dt, six_mnth_later, count(event_date_utc) as mapd_count
from
(select mem_id, first_dt, date_add(first_dt, interval 6 month) as six_mnth_later
from table2) as a
left join
(select mem_id, event_date_utc

from df.member_detail
where mapdflag = 1) as b
on a.mem_id = b.mem_id
where b.event_date_utc between a.first_dt and a.six_mnth_later
group by a.mem_id, first_dt, six_mnth_later
)
-- get final count
select count(distinct(mem_id)) as member_cnt
from table3
where mapd_count&gt;=6
-- answer: 73547

-- Using the population specified in exercise #2, create a table for the first 6 months after the
first fill month of lisinopril that contains:
-- allowed amount per member per month
-- visit count per member per month
-- proportion of members with at least one hospital admission
-- proportion of members that filled another prescription for lisinopril
-- start with exercise 2 population
------------------------------------------------------------------------------
with table1 as (
with table1 as (
select distinct a.mem_id
from
--people on lisinopril
(select distinct mem_id

from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2018-01-01' and '2018-12-31'
) as a
inner join
(
--filter to continuously enrolled mapd members in 2017-2018
select distinct(mem_id), count(year_mo) as month_cnt
from df.member_detail
-- include members which we provide prescription coverage for
where mapd_flag = 1
-- only looking at continuously enrolled members 2017-2018
and year_mo between 201701 and 201812
group by mem_id
) as b
on a.mem_id = b.mem_id
left join
(
select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2017-01-01' and '2017-12-31'
) as c
on a.mem_id = c.mem_id
-- continuously enrolled 2017-2018
where month_cnt = 24
and c.mem_id IS NULL
)
-- get the first date people took lisinopril
-- 76358 people
,table2 as (
select distinct one.mem_id, first_dt, two.first_mo
from (
(select mem_id
from table1) as one
join (
select mem_id, min(year_mo) as first_mo, min(full_dt) as first_dt
from `df.pharmacy_claim`
where year_mo between 201801 and 201812
and gnrc_nm like '%lisinopril%'

group by mem_id
) as two
on one.mem_id = two.mem_id
)
)

-- make sure people are continuously enrolled for the 6 months following first drug fill
,table3 as (
select distinct a.mem_id, first_mo, six_mnth_later, count(year_mo) as mapd_count
from
(select mem_id, first_mo, cast(format_date('%Y%m', date_add(first_dt, interval 6 month))
as int64) as six_mnth_later
from table2) as a
left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
where b.year_mo between a.first_mo and a.six_mnth_later
group by a.mem_id, first_mo, six_mnth_later
)
-- get final count
select a.mem_id, year_mo, first_mo, six_mnth_later
from (select mem_id, first_mo, six_mnth_later from table3
where mapd_count=7) as a
-- get year_mo
left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
)
------------------------------------------------------------------------------
-- start of exercise 3
-- get allowed amount and visit count from medical claims
,table2 as (
select mem_id
, year_mo
, sum(allw_amt) as allw_amt

, sum(vst_cnt) as vst_cnt
from df.medical_claim
group by mem_id, year_mo
)
-- join members, months, and claims and get month index for each person
,table3 as (
select a.mem_id
, a.year_mo
, ROW_NUMBER() OVER(PARTITION BY a.mem_id order by a.year_mo) month
-- ifnull to keep year_mos that have no medical claims as 0
, ifnull(allw_amt, 0) as allw_amt, ifnull(vst_cnt, 0) as vst_cnt
from
table1 as a
-- left join to keep people from second exercise and combine them with their medical claims
left join
table2 as b
on a.mem_id = b.mem_id
and a.year_mo = b.year_mo
-- filter to 6 months after fill
where a.year_mo &gt; a.first_mo and a.year_mo &lt;= a.six_mnth_later
)
-- calculate average pmpm allw_amt and vst_cnt
select month
, round(avg(allw_amt), 2) as pmpm_allw_amt
, round(avg(vst_cnt), 2) as pmpm_visits
from table3
group by month
order by month

4
-- 6 x 5 summary table output
-- Using the population specified in exercise #2, create a table for the first 6 months after the
first fill month of lisinopril that contains:
-- allowed amount per member per month
-- visit count per member per month
-- proportion of members with at least one hospital admission
-- proportion of members that filled another prescription for lisinopril
-- start with exercise 2 population
------------------------------------------------------------------------------
with table1 as (
with table1 as (
select distinct a.mem_id
from
--people on lisinopril
(select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2018-01-01' and '2018-12-31'
) as a
inner join
(
--filter to continuously enrolled mapd members in 2017-2018
select distinct(mem_id), count(year_mo) as month_cnt
from df.member
-- include members which we provide prescription coverage for
where mapd_flag = 1
-- only looking at continuously enrolled members 2017-2018
and year_mo between 201701 and 201812
group by mem_id
) as b
on a.mem_id = b.mem_id
left join
(
select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2017-01-01' and '2017-12-31'
) as c
on a.mem_id = c.mem_id

-- continuously enrolled 2017-2018
where month_cnt = 24
and c.mem_id IS NULL
)
-- get the first date people took lisinopril
-- 76358 people
,table2 as (
select distinct one.mem_id, first_dt, two.first_mo
from (
(select mem_id
from table1) as one
join (
select mem_id, min(year_mo) as first_mo, min(full_dt) as first_dt
from `df.pharmacy_claim`
where year_mo between 201801 and 201812
and gnrc_nm like '%lisinopril%'
group by mem_id
) as two
on one.mem_id = two.mem_id
)
)

-- make sure people are continuously enrolled for the 6 months following first drug fill
,table3 as (
select distinct a.mem_id, first_mo, six_mnth_later, count(year_mo) as mapd_count
from
(select mem_id, first_mo, cast(format_date('%Y%m', date_add(first_dt, interval 6 month))
as int64) as six_mnth_later
from table2) as a
left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
where b.year_mo between a.first_mo and a.six_mnth_later
group by a.mem_id, first_mo, six_mnth_later
)
-- get final count
select a.mem_id, year_mo, first_mo, six_mnth_later

from (select mem_id, first_mo, six_mnth_later from table3
where mapd_count=7) as a
left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
)
------------------------------------------------------------------------------
-- start of exercise 3

-- get allowed amount, visit count, and admit count from medical claims
,table2 as (
select mem_id
, year_mo
, sum(allw_amt) as allw_amt
, sum(vst_cnt) as vst_cnt
, case when sum(admit_cnt) &gt; 0 then 1 else 0 end as admit_cnt
from df.medical_claim
group by mem_id, year_mo
)
-- join members, months, and claims and get month index for each person
,table3 as (
select a.mem_id
, a.year_mo
, ROW_NUMBER() OVER(PARTITION BY a.mem_id order by a.year_mo) month
, ifnull(allw_amt, 0) as allw_amt
, ifnull(vst_cnt, 0) as vst_cnt
, ifnull(admit_cnt, 0) as admit_cnt
from
table1 as a
left join
table2 as b
on a.mem_id = b.mem_id
and a.year_mo = b.year_mo
where a.year_mo &gt; a.first_mo and a.year_mo &lt;= a.six_mnth_later
)

-- get members that filled another prescription for lisinopril

,table4 as(
select table3.mem_id
, table3.year_mo
, table3.month
, count(distinct full_dt) as refill
from table3
left join `df.pharmacy_claim` as a
on a.mem_id = table3.mem_id and a.year_mo = table3.year_mo
where gnrc_nm like '%lisinopril%'
group by table3.mem_id, table3.year_mo, month
)
-- calculate cost, visits, and prop of hospital visits by month
,table5 as (
select month
, round(avg(allw_amt), 2) as pmpm_allw_amt
, round(avg(vst_cnt), 2) as pmpm_visits
, round(avg(admit_cnt), 2) as prop_hospital_visits
, count(mem_id) as cnt
from table3
group by month
)
-- final output
select a.month
, pmpm_allw_amt
, pmpm_visits
, prop_hospital_visits
, round(refill/cnt, 2) as prop_refill -- calculate prop of lisinopril refills
from
(select count(refill &gt; 0) as refill, month
from table4
group by month) as a
inner join
table5 as b
on a.month = b.month
order by month

5
-- Using the population specified in exercise #2:
-- create a table that summarizes the distribution of count of fill dates per member, during
members' first 6 months of lisinopril
-- create a table that summarizes the distribution of days supplied per fill, during members'
first 6 months of lisinopril
-- start with exercise 2 population
------------------------------------------------------------------------------
with table1 as (
with table1 as (
select distinct a.mem_id
from
--people on lisinopril
(select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2018-01-01' and '2018-12-31'
) as a
inner join
(
--filter to continuously enrolled mapd members in 2017-2018
select distinct(mem_id), count(year_mo) as month_cnt
from df.member
-- include members which we provide prescription coverage for
where mapd_flag = 1
-- only looking at continuously enrolled members 2017-2018
and year_mo between 201701 and 201812
group by mem_id
) as b
on a.mem_id = b.mem_id
left join
(
select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2017-01-01' and '2017-12-31'
) as c
on a.mem_id = c.mem_id
-- continuously enrolled 2017-2018

where month_cnt = 24
and c.mem_id IS NULL
)
-- get the first date people took lisinopril
-- 76358 people
,table2 as (
select distinct one.mem_id, first_dt, two.first_mo
from (
(select mem_id
from table1) as one
join (
select mem_id, min(year_mo) as first_mo, min(full_dt) as first_dt
from `df.pharmacy_claim`
where year_mo between 201801 and 201812
and gnrc_nm like '%lisinopril%'
group by mem_id
) as two
on one.mem_id = two.mem_id
)
)

-- make sure people are continuously enrolled for the 6 months following first drug fill
,table3 as (
select distinct a.mem_id, first_mo, six_mnth_later, count(year_mo) as mapd_count
from
(select mem_id, first_mo, cast(format_date('%Y%m', date_add(first_dt, interval 6 month))
as int64) as six_mnth_later
from table2) as a
left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
where b.year_mo between a.first_mo and a.six_mnth_later
group by a.mem_id, first_mo, six_mnth_later
)
-- get final count
select a.mem_id, year_mo, first_mo, six_mnth_later
from (select mem_id, first_mo, six_mnth_later from table3
where mapd_count=7) as a

left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
)
------------------------------------------------------------------------------
-- start of exercise 5
-- count prescription for lisinopril refills in the next 6 months for each member
,table2 as(
select table1.mem_id
, round(avg(day_cnt), 0) as days_supplied_per_fill
--, day_cnt
, count(distinct full_dt) as refill_cnt
from table1
left join `df.pharmacy_claim` as a
on a.mem_id = table1.mem_id and a.year_mo = table1.year_mo
where gnrc_nm like '%lisinopril%'
and a.year_mo &gt; table1.first_mo and a.year_mo &lt;= table1.six_mnth_later
group by table1.mem_id--, day_cnt
)
,table3 as(
select table1.mem_id
, day_cnt days_supplied_per_fill
from table1
left join `df.pharmacy_claim` as a
on a.mem_id = table1.mem_id and a.year_mo = table1.year_mo
where gnrc_nm like '%lisinopril%'
and a.year_mo &gt; table1.first_mo and a.year_mo &lt;= table1.six_mnth_later
)
-- check people who have negative day counts
-- select mem_id, day_cnt, full_dt from `df.pharmacy_claim`
-- where mem_id in (26059293, 6694344, 28287293)
-- and gnrc_nm like '%lisinopril%'
-- and full_dt &gt; '2018-01-01'
-- order by mem_id, full_dt

-- summary statistics of refill count and day supplied per fill
-- select 'average' as sum_stat,

-- round(avg(refill_cnt), 2) as refill_cnt,
-- round(avg(days_supplied_per_fill), 2) as days_supplied_per_fill
-- from table2
-- union all
-- select 'min',
-- min(refill_cnt),
-- min(days_supplied_per_fill)
-- from table2
-- union all
-- select 'max',
-- max(refill_cnt),
-- max(days_supplied_per_fill)
-- from table2
-- union all
-- select 'sd',
-- round(stddev(refill_cnt), 2),
-- round(stddev(days_supplied_per_fill), 2)
-- from table2
-- Distribution of refills
-- select refill_cnt
-- , count(mem_id) as count
-- from table2
-- group by refill_cnt
-- order by refill_cnt
-- Distribution of day supply
select days_supplied_per_fill
, count(mem_id) as count
from table3
group by days_supplied_per_fill
order by days_supplied_per_fill

6
-- Using the population specified in exercise #2,
-- calculate the average adherence rate to lisinopril during members' first 6 months of lisinopril.
-- Adherence is defined as the proportion of days in the first 6 months that are accounted for
with days supplied of lisinopril.

-- start with exercise 2 population
------------------------------------------------------------------------------
with table1 as (
with table1 as (
select distinct a.mem_id
from
--people on lisinopril
(select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2018-01-01' and '2018-12-31'
) as a
inner join
(
--filter to continuously enrolled mapd members in 2017-2018
select distinct(mem_id), count(year_mo) as month_cnt
from df.member
-- include members which we provide prescription coverage for
where mapd_flag = 1
-- only looking at continuously enrolled members 2017-2018
and year_mo between 201701 and 201812
group by mem_id
) as b
on a.mem_id = b.mem_id
left join
(
select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2017-01-01' and '2017-12-31'
) as c
on a.mem_id = c.mem_id

-- continuously enrolled 2017-2018
where month_cnt = 24
and c.mem_id IS NULL
)
-- get the first date people took lisinopril
-- 76358 people
,table2 as (
select distinct one.mem_id, first_dt, two.first_mo
from (
(select mem_id
from table1) as one
join (
select mem_id, min(year_mo) as first_mo, min(full_dt) as first_dt
from `df_uhgrd.pharmacy_claim`
where year_mo between 201801 and 201812
and gnrc_nm like '%lisinopril%'
group by mem_id
) as two
on one.mem_id = two.mem_id
)
)

-- make sure people are continuously enrolled for the 6 months following first drug fill
,table3 as (
select distinct a.mem_id, first_mo, six_mnth_later, first_dt, six_mnth_later_dt,
count(year_mo) as mapd_count
from
(select mem_id, first_mo, cast(format_date('%Y%m', date_add(first_dt, interval 6 month))
as int64) as six_mnth_later
, first_dt, date_add(first_dt, interval 6 month) six_mnth_later_dt
from table2) as a
left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
where b.year_mo between a.first_mo and a.six_mnth_later
group by a.mem_id, first_mo, six_mnth_later, first_dt, six_mnth_later_dt
)
-- get final count

select a.mem_id, year_mo, first_mo, six_mnth_later, first_dt, six_mnth_later_dt
from (select mem_id, first_mo, six_mnth_later, first_dt, six_mnth_later_dt from table3
where mapd_count=7) as a
left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
)
------------------------------------------------------------------------------
-- start of exercise 6
-- calculate day count such that any days after 6 months later aren't counted

,table2 as(
select table1.mem_id
, day_cnt
, case
when full_dt &gt;= six_mnth_later_dt then 0
when DATE_ADD(full_dt, INTERVAL day_cnt DAY) &lt; six_mnth_later_dt then day_cnt
else DATE_DIFF(six_mnth_later_dt, full_dt, day)
end as new_day_cnt
, full_dt
, first_dt
, six_mnth_later_dt
from table1
left join `df.pharmacy_claim` as a
on a.mem_id = table1.mem_id and a.year_mo = table1.year_mo
where gnrc_nm like %lisinopril%;
and a.full_dt = table1.first_dt and a.full_dt = table1.six_mnth_later_dt
)
-- count prescription for lisinopril refills in the next 6 months for each member
,table3 as (
select mem_id
, round(avg(new_day_cnt), 0) * count(distinct full_dt) as days_filled
, DATE_DIFF(max(six_mnth_later_dt), max(first_dt), day) as total_days
from table2
group by table2.mem_id
)

-- calculate adherence rate, and set rates greater than 1 to 1
, table4 as (
select case
when days_filled / total_days &gt; 1 then 1
else days_filled / total_days
end as adherence_rate
from table3
)
-- calculate average adherence rate
select avg(adherence_rate) as avg_adherence_rate from table4
-- Answer: 0.7625

-- exercise 7
-- Using the population specified in exercise #2, create a table for the first 6 months after the
first fill month of lisinopril that contains:
-- allowed amount per member per month
-- visit count per member per month
-- proportion of members with at least one hospital admission
-- proportion of members that filled another prescription for lisinopril
-- start with exercise 2 population
------------------------------------------------------------------------------
with table1 as (
with table1 as (
select distinct a.mem_id
from
--people on lisinopril

(select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2018-01-01' and '2018-12-31'
) as a
inner join
(
--filter to continuously enrolled mapd members in 2017-2018
select distinct(mem_id), count(year_mo) as month_cnt
from df.member
-- include members which we provide prescription coverage for
where mapd_flag = 1
-- only looking at continuously enrolled members 2017-2018
and year_mo between 201701 and 201812
group by mem_id
) as b
on a.mem_id = b.mem_id
left join
(
select distinct mem_id
from `df.pharmacy_claim`
where gnrc_nm like '%lisinopril%'
and full_dt between '2017-01-01' and '2017-12-31'
) as c
on a.mem_id = c.mem_id
-- continuously enrolled 2017-2018
where month_cnt = 24
and c.mem_id IS NULL
)
-- get the first date people took lisinopril
-- 76358 people
,table2 as (
select distinct one.mem_id, first_dt, two.first_mo
from (
(select mem_id
from table1) as one
join (
select mem_id, min(year_mo) as first_mo, min(full_dt) as first_dt
from `df.pharmacy_claim`
where year_mo between 201801 and 201812

and gnrc_nm like '%lisinopril%'
group by mem_id
) as two
on one.mem_id = two.mem_id
)
)

-- make sure people are continuously enrolled for the 6 months following first drug fill
,table3 as (
select distinct a.mem_id, first_mo, six_mnth_later, count(year_mo) as mapd_count
from
(select mem_id, first_mo, cast(format_date('%Y%m', date_add(first_dt, interval 6 month))
as int64) as six_mnth_later
from table2) as a
left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
where b.year_mo between a.first_mo and a.six_mnth_later
group by a.mem_id, first_mo, six_mnth_later
)
-- get final count
select a.mem_id, year_mo, first_mo, six_mnth_later
from (select mem_id, first_mo, six_mnth_later from table3
where mapd_count = 7) as a
left join
(select mem_id, year_mo
from df.member
where mapd_flag = 1) as b
on a.mem_id = b.mem_id
)

-- diagnoses in 2018
,table2 as (
select mem_id, substr(dx1_cd, 1, 4) as ICD10_cd, dx1_fst3_desc
from df.medical_claim
where year_mo between 201801 and 201812
and mem_id in (select mem_id from table1)
)

-- members with each diagnosis
select ICD10_cd, dx1_fst3_desc, count(mem_id) as members
from table2
group by ICD10_cd, dx1_fst3_desc
order by members desc

