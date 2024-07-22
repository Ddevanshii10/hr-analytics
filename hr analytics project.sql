use hr_analytics;

select * from countries;

select * from departments;

select * from employees;

select * from job_history;

select * from jobs;

select * from locations;

select * from regions;

use hr_analytics; 

# total number of employees in the company 
select count(*) as total_employees
from employees;

-- number of employees in each department
select  e.department_id, d.department_name, count(*) as number_of_employees
from employees e 
left join departments d
on e.department_id = d.department_id
group by e.department_id;

-- average salary department wise
select e.department_id, avg(e.salary) as avg_salary
from employees e
left join departments d
on e.department_id = d.department_id
group by e.department_id
order by avg_salary asc;

-- number of employees in each country
select c.country_name, count(e.employee_id) as number_of_employees
from employees e 
join departments d on e.department_id = d.department_id
join locations l on d.location_id = d.location_id
join countries c on l.country_id = c.country_id
group by c.country_name;

-- List all job titles along with the number of employees holding each title.
select j.job_title, count(e.employee_id) as employee_count
from employees e
join jobs j on j.job_id = e.job_id
group by job_title
order by employee_count desc;

-- Identify the departments with the highest and lowest average salaries.

-- department with hisghest salary 
(select d.department_name, round(avg(e.salary),2) as avg_salary
from employees e 
join departments d 
on e.department_id = d.department_id
group by d.department_name
order by avg_salary desc
limit 1)
union
-- department with lowest salary 
(select d.department_name, round(avg(e.salary),2) as avg_salary
from employees e 
join departments d 
on e.department_id = d.department_id
group by d.department_name
order by avg_salary asc
limit 1);

-- Calculate the tenure (in years) of each employee based on their hire date.
select concat(e.first_name," ",e.last_name) as full_name,
	round(case
		when max(jh.end_date) is not null then datediff(max(jh.end_date),e.hire_date)/365
        else datediff(curdate() ,e.hire_date)/365
        end, 2) as tenure
from employees e 
left join job_history jh
on e.employee_id = jh.employee_id and e.job_id = jh.job_id
group by e.employee_id, full_name, e.hire_date
order by tenure desc;

-- Create a report showing the distribution of salaries within each job title.
select j.job_title, 
	count(e.employee_id) as employee_count,
    min(e.salary) as min_salary,
    max(e.salary) as max_salary,
	floor(avg(e.salary)) as avg_salary,
    round(stddev(e.salary),2) as std_deviation_slary
from employees e 
left join jobs j 
on e.job_id = j.job_id
group by j.job_title
order by avg_salary desc;

-- List all employees who do not have a manager.
select employee_id, first_name, last_name, manager_id, department_id
from employees 
where manager_id is null;

--  Find the department(s) that have the most number of locations associated with them.
with location_counts as
(select d.department_id, d.department_name,
	count(distinct d.location_id) as location_count
from departments d
join locations l 
on d.location_id = l.location_id 
group by d.department_id
)
select department_name, location_count
from location_counts 
where location_count = (select max(location_count) from location_counts);

-- Determine which country has the highest number of employees.
select c.country_name, 
	count(e.employee_id) as num_employees
from employees e
join departments d on e.department_id = d.department_id
join locations l on d.location_id = d.location_id
join countries c on l.country_id = c.country_id
group by c.country_name
order by num_employees 
limit 1;

-- Compare average salaries for the same job title across different regions and countries. Identify any significant disparities.
-- using common table expression
with SalaryData as (
	select e.job_id, j.job_title, r.region_name, c.country_name, e.salary
    from employees e
    join departments d on e.department_id = d.department_id
    join locations l on d.location_id = l.location_id 
    join countries c on l.country_id = c.country_id
    join regions r on c.region_id = r.region_id
    join jobs j on e.job_id = j.job_id
)
select job_title, region_name, country_name,
	avg(salary) as avg_salary
from SalaryData
group by job_title, region_name, country_name
order by job_title, region_name, avg_salary desc;
    
-- /*Analyze historical job history data to understand employee turnover patterns.*/ --

-- average turnover rate 
with AnnualDepartures as ( 
select year(jh.end_date) as year_of_departure, 
		count(distinct jh.employee_id) as num_departures
	from job_history jh
	where jh.end_date is not null
	group by jh.end_date
)

-- Annual employees each year
, AnnualAvgEmployees as(
	select year(hire_date) as year_of_hire_date,
		count(distinct employee_id) as num_hired
    from employees
    group by year_of_hire_date
)

-- combine ctes to calculate turnover rate
select a.year_of_departure, a.num_departures,
	coalesce(b.num_hired, 0)  as num_hired,
    round(a.num_departures/nullif(b.num_hired,0) *100,2) as turnover_rate
from AnnualDepartures a
left join AnnualAvgEmployees b on a.year_of_departure = b.year_of_hire_date
order by a.year_of_departure;

-- step-2 average tenure of departed employees
SELECT 
	ROUND(AVG(DATEDIFF(jh.end_date, e.hire_date) / 365.25), 2) AS avg_tenure
FROM employees e
JOIN job_history jh ON e.employee_id = jh.employee_id
WHERE jh.end_date IS NOT NULL;

-- step 3 - turnover by department and job title

-- turnover by department
with DepartmentTurnover as (
	select d.department_id, d.department_name, 
		count(distinct jh.employee_id) as num_departures
	from job_history jh
    join employees e on jh.employee_id = e.employee_id
    join departments d on e.department_id = d.department_id
    where jh.end_date is not null 
    group by d.department_id , d.department_name
),

DepartmentSize as(
	select d.department_id,
		count(distinct e.employee_id) as num_employees
	from departments d
    join employees e on e.department_id = d.department_id
    group by d.department_id
)

-- combine two ctes to calculate turnover rate
select dt.department_name, dt.num_departures, ds.num_employees,
	round(dt.num_departures / nullif(ds.num_employees, 0) *100, 2) as turnover_rate
from DepartmentTurnover dt
join DepartmentSize ds on dt.department_id = ds.department_id
order by turnover_rate desc;

-- turnover by job title
with JobTitleTurnover as (
	select j.job_id, j.job_title,
		count(distinct jh.employee_id) as num_departures
	from job_history jh 
    join employees e on jh.employee_id = e.employee_id
    join jobs j on j.job_id = e.job_id 
    where jh.end_date is not null
    group by j.job_id, j.job_title
),

JobTitleSize as(
	select j.job_id, 
		count(distinct e.employee_id) as  num_employees 
	from jobs j
    join employees e on j.job_id = e.job_id 
    group by j.job_id
)

-- combine two ctes to calculate turnover rate
SELECT 
    jt.job_title,
    jt.num_departures,
    js.num_employees,
    ROUND(jt.num_departures / NULLIF(js.num_employees, 0) * 100, 2) AS turnover_rate
FROM 
    JobTitleTurnover jt
JOIN 
    JobTitleSize js ON jt.job_id = js.job_id
ORDER BY 
    turnover_rate DESC;