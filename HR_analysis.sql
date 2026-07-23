create database Hr_Analysis;
-- insert table throught python hr_employees
use hr_analysis;
select * from hr_employees;

--  1) Attrition Thresholdes and Turning Points 

SELECT 
    distance_category,
    COUNT(EmployeeNumber) AS total_Employee,
    SUM(attrition_flag) AS total_attrition,
    CONCAT(ROUND((SUM(attrition_flag) / COUNT(EmployeeNumber)) * 100),
            '%') AS Attrition_rate_percentage
FROM
    (SELECT 
        EmployeeNumber,
            Attrition,
            CASE
                WHEN DistanceFromHome <= 5 THEN '1. Near (1-5)'
                WHEN DistanceFromHome <= 10 THEN '2. Moderate (6-10)'
                WHEN DistanceFromHome <= 15 THEN '3. commute (11-15)'
                ELSE '4. Far (+16) '
            END AS distance_category,
            CASE
                WHEN Attrition = 'Yes' THEN 1
                ELSE 0
            END AS attrition_flag
    FROM
        hr_employees) t1
GROUP BY 1
ORDER BY 1; 
 
 /* insight: The distance Threshold is 10 km .
			 Employees commuting more than 10 km show a sudden 50% increase 
			 in attrition rate (from 14% to 21%+),indicate travel burnout
 */

 -- 2) job hopper profile
 
 
SELECT 
    NumCompaniesWorked_category,
    COUNT(EmployeeNumber) AS total_Employee,
    SUM(attrition_flag) AS total_attrition,
    CONCAT(ROUND((SUM(attrition_flag) / COUNT(EmployeeNumber)) * 100),
            '%') AS Attrition_rate_percentage
FROM
    (SELECT 
        EmployeeNumber,
            Attrition,
            CASE
                WHEN NumCompaniesWorked = 0 THEN '1. Fresher '
                WHEN NumCompaniesWorked <= 4 THEN '2. MOderate switcher <4 '
                ELSE '3. job Hooper >5'
            END AS NumCompaniesWorked_category,
            CASE
                WHEN Attrition = 'Yes' THEN 1
                ELSE 0
            END AS attrition_flag
    FROM
           hr_employees) t1
GROUP BY 1
ORDER BY 1;
 
 
 /* Past behavior predict future turnover. Employees who have worked in 5+ prior companies 
 (Job Hoppers) exhibit a 22% attrition rate, 
 which is nearly double the attrition rate of Fresher (12%)
 */ 

 -- 3)Compensation & Loyalty Paradox (cost vs Retention)
 
with roleExeriencedData as ( 
   select EmployeeNumber,JobRole,JobLevel,
           YearsAtCompany, TotalWorkingYears, MonthlyIncome ,
	       case when YearsAtCompany >=4 then 'Tenured'
			    when YearsAtCompany <=1 and TotalWorkingYears >=5 
                       then 'Lateral Hire'  
				else ("3. other employees")
           end as employee_type    
	from hr_employees 
) 
    select jobRole,joblevel, employee_type,
           count(EmployeeNumber) as total_employees,
           round(avg(MonthlyIncome),2) as avg_income 
	from roleExeriencedData 
	where employee_type in ('Tenured','Lateral Hire')    
	group by 1,2,3 order by 1,2,3 ;
    
/* finding across all job roles loyal employees (4+ year) earn
 consistently higher average monthly income than 
 newly hired experience market professionals 

buisness impact : excellent internal pay equity . the company actively reward tenure and internal 
growth rather than overpaying for external talent help in long term retention.

Risk :External experienced hires are being underpaid compared to internal peers,
creating a high early -stage attrition risk as new talent may feel undervalued

recommendation: implement a 'new hire pay floor ' to 
 ensure external talent is benchmarked closer to the internal average, 
 protecting the organization from early stage turnover of experienced proffessionals. */

-- 4.  the underrated high performer 
with RolelevelAvgIncome as (
select EmployeeNumber,JobRole,JobLevel,
       JobSatisfaction,MonthlyIncome,
       PercentSalaryHike,PerformanceRating ,
	  avg(MonthlyIncome)over(partition by jobRole,Joblevel) as avg_group_income ,
      Attrition
from hr_employees
) 
select 
  EmployeeNumber,JobRole,JobLevel,
  MonthlyIncome,round(avg_group_income) as avg_Group_income ,
  JobSatisfaction,PerformanceRating,PercentSalaryHike,Attrition ,
  case when MonthlyIncome < avg_Group_income and 
      PerformanceRating  = 4 then 'underrated'  else 'fairely paid' end as Salary_status
from  RolelevelAvgIncome 
where PerformanceRating  = 4 
order by 2,3,4 asc      
;
/* 
insight : The performance-pay Disconnect 
the pattern (data proof) :the ibm dataset , a performanceRating of 4 automatically 
guarentees a high percentage hike (>=20%) 

the core issue : 
However,despite receiving high percentage hikes , 
134 top-performing employees are still
earning below the average monthly income of their specific job Role and job level peers 

Buisness impact: 
High risk of 'Appraisal illusion' . even though HR is giving them a 20% hike , 
their base salary remains low that they 
are still underpaid compared to internal peers,making them highly vulnerable to competitive poaching.
*/


-- Manager and career growth 
-- 5 How do manager tenure and promotion status affect employee attrition?

with promotionstagnentstaff as ( 
select  EmployeeNumber,YearsWithCurrManager,YearsSinceLastPromotion ,attrition ,
		case when YearsWithCurrManager <=1  then '1. New manager' 
             when YearsWithCurrManager <=3 then '2. Stable phase manager (2-3)year'
             when YearsWithCurrManager <=6 then '3. stagnation Phase manager (4-6)year'
             else '4. Highly stagnant(7+year) manager'
		end as Manager_tenure_bucket ,
        
        case when YearsSinceLastPromotion =0  then '1. recently promoted' 
             when YearsSinceLastPromotion <=3 then '2. (1-3) last promotion'
             when YearsSinceLastPromotion <=6 then '3. (4-6) last promotion'
             else '4. (7+year) last promotion '
		end as promotion_status,
        
		CASE WHEN Attrition = 'Yes' THEN 1
			   ELSE 0
	    END AS attrition_flag
from hr_employees
)
select Manager_tenure_bucket, promotion_status,
	   count(EmployeeNumber) total_employee ,
       sum(attrition_flag) as total_attrition,
       concat(round((sum(attrition_flag) / count(EmployeeNumber) ) * 100 ,2),'%') as AttritionRate_percentage 
from promotionstagnentstaff 
group by 1,2 order by 2,1;

/*
Observation : 
Employees working under new managers have the highest attrition rate 
(around 28–30%) across promotion categories.
Employees with stable managers (2–6 years) show comparatively lower attrition (around 11–14%).
Employees who were recently promoted still show high attrition, especially when reporting to a new manager.
Categories with very few employees (for example, 7–24 employees) show fluctuating percentages, 
so those results should be interpreted carefully.
Business Insight : 
Manager stability appears to have a stronger relationship with employee retention than promotion status alone.
Promotion by itself does not guarantee that employees will stay. 
Even recently promoted employees show high attrition when they are working under newly appointed managers.
This suggests that leadership transition may be an important factor influencing employee retention.
Recommendation : 
HR should provide additional support and onboarding for new managers to help 
them build strong relationships with their teams.
Employees who receive recent promotions should be monitored during the first few months, 
especially if they are also assigned to a new manager.
Conduct stay interviews and feedback sessions to identify issues early and reduce attrition.
*/ 

-- 6 Relationship between promotion and attrition 


with promotionstagnentstaff as ( 
select  EmployeeNumber,YearsWithCurrManager,YearsSinceLastPromotion ,attrition ,
	case when YearsSinceLastPromotion =0  then '1. recently promoted' 
             when YearsSinceLastPromotion <=3 then '2. (1-3) last promotion'
             when YearsSinceLastPromotion <=6 then '3. (4-6) last promotion'
             else '4. (7+year) last promotion '
		end as promotion_status,
        
		CASE WHEN Attrition = 'Yes' THEN 1
			   ELSE 0
	    END AS attrition_flag
from hr_employees
)
select  promotion_status,
	   count(EmployeeNumber) total_employee ,
       sum(attrition_flag) as total_attrition,
       concat(round((sum(attrition_flag) / count(EmployeeNumber) ) * 100 ,2),'%') as AttritionRate_percentage 
from promotionstagnentstaff 
group by 1 order by 1;

/* the relationship between promotion  and attrition is not linear both recently promoted employees
 and employees waiting a very long time for promotion execution relatively higher attrition. 
*/

--  7. Enviornment and sentiment Mismatch

select * from hr_employees; 
select EmployeeNumber,EnvironmentSatisfaction,
	   JobSatisfaction,RelationshipSatisfaction ,
       WorkLifeBalance,Attrition 
from hr_employees;
select  case when  EnvironmentSatisfaction >= 3 then " Healthy workplace Environment"
              else 'Low workplace Environment' end as Environment_Quality,
		CASE WHEN  JobSatisfaction <= 2 and RelationshipSatisfaction <=2 then ' Low Employee Engagement '
			 when JobSatisfaction >= 3 and RelationshipSatisfaction >=3 then ' High Employee Engagement '
         else " Moderate Employee Engagement" END as personal_sentiments ,
         count(*) as total_employee , 
         concat(round(count(*) * 100.0 / sum(count(*)) over() ,2),'%') as per_of_total_work_force,
         sum(case when Attrition = 'Yes' then 1 else 0 end) as total_attriton ,
         concat( round( sum(case when Attrition = 'Yes' then 1 else 0 end) * 100.0 / count(*) ,2),'%') 
         as rate_attrition
from hr_employees
group by 1,2 
order by 6 desc;

/* 
The Safe Majority: The vast majority of the company's workforce is completely stable;
employees with balanced or high environment and personal sentiment ratings
make up the largest chunk of the organization, showing historically low attrition rates.

High Rate vs. Low Impact: While the combination of Low environment and poor personal
 sentiment triggers the absolute highest attrition rate at 33.73%, it is highly concentrated
 and applies to only a small 5.6% pocket of the total population (83 employees).

The Immediate Crisis: Out of those 83 critical-risk employees, 28 have already left. 
HR's immediate, laser-focused objective must be to run diagnostic checks on the remaining 55 active employees
 to address their specific pain points before they exit.

Strategic HR Value: This proves to HR that instead of making expensive, 
sweeping company-wide policy or infrastructure updates, they can save the
remaining high-risk talent through micro-targeted team interventions and localized manager counseling.

*/


-- 8  training vs retention  

select * from hr_employees;
select case   when  TrainingTimesLastYear <=1  then '1. low training (0-1 sessions)' 
              when    TrainingTimesLastYear <=3  then '2. Mid training (2-3 sessions)'
              when  TrainingTimesLastYear >=4  then '3. High training (4-6 sessions)' end as training_frequency,
		 count(*) as total_employee,
         concat(round(count(*) * 100.0 / sum(count(*)) over() ,2),'%') as per_employee,
		 sum(case when Attrition = 'Yes' then 1 else 0 end) as total_attriton ,
         concat( round( sum(case when Attrition = 'Yes' then 1 else 0 end) * 100.0 / count(*) ,2),'%') as 
         Rate_Attrition 
from hr_employees 
group by 1 
order by 1; 


select  case when YearsAtCompany <1 then '1. new employee (0-1)' 
             when YearsAtCompany <=5 then '2. mid employee (2-5)' 
			 else  '3. old employee +6 ' end as Employee_atCompany 

, case   when  TrainingTimesLastYear <=1  then '1. low training (0-1 sessions)' 
              when    TrainingTimesLastYear <=3  then '2. Mid training (2-3 sessions)'
              when  TrainingTimesLastYear >=4  then '3. High training (4-6 sessions)' end as training_frequency,
		 count(*) as total_employee,
         concat(round(count(*) * 100.0 / sum(count(*)) over() ,2),'%') as per_employee,
		 sum(case when Attrition = 'Yes' then 1 else 0 end) as total_attriton ,
         concat( round( sum(case when Attrition = 'Yes' then 1 else 0 end) * 100.0 / count(*) ,2),'%') as 
         Rate_Attrition 
from hr_employees 
group by 1 ,2
order by 1,2; 

select Department, case   when  TrainingTimesLastYear <=1  then '1. low training (0-1 sessions)' 
              when    TrainingTimesLastYear <=3  then '2. Mid training (2-3 sessions)'
              when  TrainingTimesLastYear >=4  then '3. High training (4-6 sessions)' end as training_frequency,
		 count(*) as total_employee,
         concat(round(count(*) * 100.0 / sum(count(*)) over() ,2),'%') as per_employee,
		 sum(case when Attrition = 'Yes' then 1 else 0 end) as total_attriton ,
         concat( round( sum(case when Attrition = 'Yes' then 1 else 0 end) * 100.0 / count(*) ,2),'%') as 
         Rate_Attrition 
from hr_employees 
group by 1 ,2 
order by 1,2; 
-- here in every department or 
-- every fresher or old employee attrition rate are decrease at respect to trainning session 


-- 9 the high-Flier Burnout (BuisnessTravel+WorkLifeBalance)
select distinct BusinessTravel from hr_employees;
select * from hr_employees;
select BusinessTravel,WorkLifeBalance,count(BusinessTravel) as Total_employee,
	   sum(case when Attrition = 'Yes' then 1 else 0 end ) as total_attrition ,
       concat(round(sum(case when Attrition = 'Yes' then 1 else 0 end )  / count(BusinessTravel)  * 100 ,2),'%')
       as Attrition_rate
 from hr_employees 
group by 1 ,2 order by 2,1 ;


select BusinessTravel,count(BusinessTravel) as Total_employee,
	   sum(case when Attrition = 'Yes' then 1 else 0 end ) as total_attrition ,
       concat(round(sum(case when Attrition = 'Yes' then 1 else 0 end )  / count(BusinessTravel)  * 100 ,2),'%')
       as Attrition_rate
 from hr_employees group by 1  order by 4 desc; 

/*  The Constant Travel Burnout: Frequent travel acts as an independent trigger for attrition;
 regardless of how good their work-life balance is, employees who Travel_Frequently consistently 
 maintain the highest attrition rates between 22.73% and 46.15%.

The Corporate Baseline: The vast majority of the company's workforce falls under Travel_Rarely 
(e.g., 639 employees at WorkLifeBalance 3), which represents the stable,
desk-bound operational core of the business.

The Compounded Risk: The absolute worst-case scenario occurs when frequent
 travel meets poor personal time (WorkLifeBalance = 1), causing a massive attrition spike of 46.15%.

HR Recommendation: Do not rely on general work-life perks to save frequent travelers;
 HR must introduce specific travel-caps, mandatory rest periods, 
 or higher travel allowances to combat direct physical burnout.

*/

-- 10 StockOption vs attrition 
select StockOptionLevel,count(*) as Total_employee,
	   sum(case when Attrition = 'Yes' then 1 else 0 end ) as total_attrition ,
       concat(round(sum(case when Attrition = 'Yes' then 1 else 0 end )  / count(BusinessTravel)  * 100 ,2),'%')
       as Attrition_rate
 from hr_employees 
group by 1  order by 1; 
/*
The Equity Anchor: Offering basic stock options drops employee attrition drastically 
from a high of 24.41% (Level 0) down to a stable 9.40% (Level 1),
 proving that equity acts as a major loyalty anchor

The No-Stock Flight Risk: Employees with zero stock options (Level 0) represent the 
largest volume of exits, accounts for 154 out of the total attrition cases.

The Senior Executive Twist: Attrition spikes back up to 17.65% at Level 3, 
indicating that high-equity senior staff are heavily head-hunted by external 
competitors despite top-tier stock benefits.

HR Recommendation: Ensure all core mid-level employees get at least Level 1 stock
options to drastically reduce baseline leakage, and review non-monetary retention benefits
 for Level 3 executives.
*/

-- 11. is gender affect attrition?
select Gender,MaritalStatus,count(*),
sum(case when Attrition = 'Yes' then 1 else 0 end ) as total_attrition ,
concat(round(sum(case when Attrition = 'Yes' then 1 else 0 end )  / count(*)  * 100 ,2),'%')
       as Attrition_ratefrom  from hr_employees group by 1,2 order by 1,2;

select Gender,BusinessTravel,count(*),
sum(case when Attrition = 'Yes' then 1 else 0 end ) as total_attrition ,
concat(round(sum(case when Attrition = 'Yes' then 1 else 0 end )  / count(*)  * 100 ,2),'%')
       as Attrition_ratefrom  from hr_employees group by 1,2 order by 1,2;
       
-- 12  which factor affect the most attrition 
       
-- 1. Travel Burnout Factor
SELECT 
    'Business Travel' AS Factor_Category,
    'Travel Frequently' AS High_Risk_Condition,
    COUNT(*) AS Total_Employee,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS Total_Attrition,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS Attrition_Rate
FROM hr_employees
WHERE BusinessTravel = 'Travel_Frequently'

UNION ALL

-- 2. Equity / Compensation Factor
SELECT 
    'Stock Options',
    'Level 0 (No Stocks)',
    COUNT(*),
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees
WHERE StockOptionLevel = 0

UNION ALL

-- 3. Personal Time Factor
SELECT 
    'Work Life Balance',
    'Rating 1 (Bad Balance)',
    COUNT(*),
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees
WHERE WorkLifeBalance = 1

UNION ALL

-- 4. Environment / Infrastructure Factor
SELECT 
    'Work Environment',
    'Low Environment (1-2)',
    COUNT(*),
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees
WHERE EnvironmentSatisfaction <= 2

UNION ALL

-- 5. Training / Growth Factor
SELECT 
    'Training Frequency',
    'Low Training (0-1 Sessions)',
    COUNT(*),
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees
WHERE TrainingTimesLastYear <= 1 

-- 6. Distance factor

UNION ALL
select 'DistanceFromHom','Long_distance 10-22',count(*),
 SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees 
where DistanceFromHome between 10 and 23

-- 7.Environment Factor 
UNION ALL
select 'EnvironmentSatisfaction','Low satisfaction 1 ',count(*),
 SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees 
where EnvironmentSatisfaction = 1

-- 8. low job involment
UNION ALL
select 'JobInvolvement','Low JobInvolvement 1 ',count(*),
 SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees 
where JobInvolvement = 1

-- 9.Jobsatisfaction factor
UNION ALL
select 'JobSatisfaction','Low JobSatisfaction 1 ',count(*),
 SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees 
where JobSatisfaction = 1

-- 10 Overtimefactor 
UNION ALL
select 'OverTime','OverTime yes ',count(*),
 SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees 
where OverTime = 'yes'

-- 11 Relationships factor

UNION ALL
select 'RelationshipSatisfaction','RelationshipSatisfaction 1 ',count(*),
 SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)
FROM hr_employees 
where RelationshipSatisfaction = 1
ORDER BY Attrition_Rate DESC ;


--  13 Predictive Risk matrix

select case when JobInvolvement = 1 and OverTime = 'Yes' then ' 1.High Risk (Critical)'
			when WorkLifeBalance = 1 and OverTime = 'Yes' then ' 1.High Risk (Critical)'
            when BusinessTravel = 'Travel_Frequently' and WorkLifeBalance = 1 then ' 1.High Risk (Critical)' 
            
			when OverTime = 'Yes' then ' 2.medium Risk (Warning)'
			when JobInvolvement <=2 and StockOptionLevel = 0 then ' 2.medium Risk (Warning)'
            when BusinessTravel = 'Travel_Frequntly' then '2. Medium Risk (Warning)'
            
            else ' 3.Low Risk'
		end as Flight_Risk_category , count(*)  as total_attrition , 
        SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) as total_attrition_rate ,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) as past_attrition_rate 

from hr_employees 
group by 1 
order by 4 desc;
 
 
 -- list of employee 
select EmployeeNumber, JobRole,Department,JobInvolvement,OverTime,WorkLifeBalance,BusinessTravel,StockOptionLevel,
       case when JobInvolvement = 1 and OverTime = 'Yes' then ' 1.High Risk (Critical)'
			when WorkLifeBalance = 1 and OverTime = 'Yes' then ' 1.High Risk (Critical)'
            when BusinessTravel = 'Travel_Frequently' and WorkLifeBalance = 1 then ' 1.High Risk (Critical)' 
            
			when OverTime = 'Yes' then ' 2.medium Risk (Warning)'
			when JobInvolvement <=2 and StockOptionLevel = 0 then ' 2.medium Risk (Warning)'
            when BusinessTravel = 'Travel_Frequntly' then '2. Medium Risk (Warning)'
            
            else 'Low Risk'
		end as Flight_Risk_category
from hr_employees 
where Attrition = 'No'
order by 9;

/* 
High-Risk Precision: The model successfully isolates a critical segment of 55 employees
who carry a dangerous historical attrition rate of 47.27%. This means nearly 1 out of every 2
active employees falling into this bucket is highly likely to exit soon.

Volume vs. Risk Intensity: 
While the Medium Risk tier holds the largest volume of actual past exits (138 attritions at a 26.74% rate),
the High Risk group represents the most immediate, intense threat to business continuity.

Workforce Stability: A massive majority of 899 employees are classified under Low Risk,
 showing an incredibly stable baseline attrition rate of just 8.12%.

Strategic HR Action: HR should bypass generic retention plans and execute immediate, 
targeted micro-interventions for the active individuals flagged in the High-Risk (Critical) tier 
to prevent imminent talent loss.
*/


