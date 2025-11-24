/*
=====================================================================
Quality Checks
=====================================================================
Script Purpose:
  This script performs various quality checks for data consistency, accuracy,
  and standardization across the 'silver' schemas. It includes checks for:
  - Null or duplicate primary keys.
  - Unwanted spaces in string fields.
  - Data standardization and consistency.
  - Invalid date ranges and orders.
  - Data consistency between related fields.

Usage Notes:
  - Run these checks after data loading Silver Layer.
  - Investigate and resolve any discrepancies found during the checks.
================================================================================
*/

--=======================================================================
--checking 'silver.crm_cust_info'
--=========================================================================
--check for nulls or duplicates in primary key 
--Exception: No Result

select cst_id,count(*)
from bronze.crm_cust_info
group by cst_id
having count(*)>1 or cst_id is null;

select
*
from(
select *,
row_number() over(partition by cst_id order by cst_create_date desc) as flag_last
from bronze.crm_cust_info)t where flag_last =1 and cst_id=29466;

--check for unwanted spaces
--Expectation: No Result
select cst_firstname
from bronze.crm_cust_info
where cst_firstname != trim(cst_firstname);

select cst_lastname
from bronze.crm_cust_info
where cst_lastname != trim(cst_lastname);

select cst_gndr
from bronze.crm_cust_info
where cst_gndr != trim(cst_gndr);

select
cst_id,cst_key,
trim(cst_firstname) as cst_firstname,
trim(cst_lastname) as cst_lastname,
cst_material_status,
cst_gndr,
cst_create_date
from(
select *,
row_number() over(partition by cst_id order by cst_create_date desc) as flag_last
from bronze.crm_cust_info)t where flag_last =1;

--Data Standardization & Consistency
select distinct(cst_gndr)
from bronze.crm_cust_info;

select
cst_id,cst_key,
trim(cst_firstname) as cst_firstname,
trim(cst_lastname) as cst_lastname,
case when upper(trim(cst_material_status))='S' then 'Single'
     when upper(trim(cst_material_status))='M' then 'Married'
     else 'n/a'
    end cst_material_status,

case when upper(trim(cst_gndr))='F' then 'Female'
     when upper(trim(cst_gndr))='M' then 'Male'
     else 'n/a'
    end cst_gndr,
cst_create_date
from(
select *,
row_number() over(partition by cst_id order by cst_create_date desc) as flag_last
from bronze.crm_cust_info
where cst_id is not null
) as t where flag_last=1
  
--=======================================================================
--checking 'silvder.crm_prd_info'
--=========================================================================


select * from bronze.crm_prd_info;
-------
select
prd_id,
prd_key,
replace(substring(prd_key,1,5),'-','_') as cat_id,
substring(prd_key,7,len(prd_key)) as prd_key,
prd_nm,
isnull(prd_cost,0) as prd_cost,
case when upper(trim(prd_line))='M' then 'Mountain'
     when upper(trim(prd_line))='R' then 'Road'
     when upper(trim(prd_line))='S' then 'Other Sales'
     when upper(trim(prd_line))='S' then 'Touring'
     else 'n/a'
end as prd_line,
CAST(prd_start_dt as date) as prd_start_dt,
CAST(lead(prd_start_dt) over (partition by prd_key order by prd_start_dt)-1 as date) as prd_end_dt_test
from bronze.crm_prd_info;
-----------
select sls_prd_key from bronze.crm_sales_details;
---------
select distinct id from bronze.erp_px_cat_g1v2;
---------
SELECT 
prd_id,
count(*)
from bronze.crm_prd_info
group by prd_id
having count(*)>1 or prd_id is null;
----------
---check for unwanted spaces
--expectation: No Results
select prd_nm
from bronze.crm_prd_info
where prd_nm!=trim(prd_nm)
------------------
--check for NULLS or Negative Numbers
--expectation: No Results
-----------------
select prd_cost
from bronze.crm_prd_info
where prd_cost is null or prd_cost<0;
----------------------
--Data standardization & consistency
select distinct prd_line
from bronze.crm_prd_info;
----------------------
--check for Invalid Date Orders
select * 
from bronze.crm_prd_info
where prd_end_dt<prd_start_dt
-------------------
--changing dates logic 
select prd_id,
prd_key,
prd_nm,
prd_start_dt,
prd_end_dt,
lead(prd_start_dt) over (partition by prd_key order by prd_start_dt)-1 as prd_end_dt_test
from bronze.crm_prd_info
where prd_key in('AC-HE-HL-U509-R','AC-HE-HL-U509')


--=======================================================================
--checking 'silver.crm_sales_details'
--=========================================================================
SELECT
sls_ord_num,
sls_prd_key,
sls_cust_id,
case when sls_order_dt=0 or len(sls_order_dt) !=8 then null
     else cast(cast(sls_order_dt as varchar) as date)
end as sls_order_dt,

case when sls_ship_dt=0 or len(sls_ship_dt) !=8 then null
     else cast(cast(sls_ship_dt as varchar) as date)
end as sls_ship_dt,

case when sls_due_dt=0 or len(sls_due_dt) !=8 then null
     else cast(cast(sls_due_dt as varchar) as date)
end as sls_ship_dt,

case when sls_sales is null or sls_sales <=0 or sls_Sales != sls_quantity*ABS(sls_price)
     then sls_quantity*ABS(sls_price)
    else sls_sales
end as sls_sales,

case when sls_price is null or sls_price <=0 
     then sls_sales/nullif(sls_quantity,0)
   else sls_price
end as sls_price,

sls_quantity
FROM bronze.crm_sales_details;

----------
select 
nullif(sls_order_dt,0) sls_order_dt
from bronze.crm_sales_details
where sls_order_dt <=0 
or len(sls_order_dt)!=8
or sls_order_dt>20500101
or sls_order_dt<19000101;

----------
select * from bronze.crm_sales_details;
----------
select sls_sales
from bronze.crm_sales_details
where sls_sales <0 or sls_sales is null;
---
select isnull(sls_sales,0) 
from bronze.crm_sales_details
where sls_sales is null;

---
select distinct
sls_sales as old_sls_sales,
sls_quantity as old_sls_quantity,
sls_price as old_sls_price,

case when sls_sales is null or sls_sales <=0 or sls_Sales != sls_quantity*ABS(sls_price)
     then sls_quantity*ABS(sls_price)
    else sls_sales
end as sls_sales,

case when sls_price is null or sls_price <=0 
     then sls_sales/nullif(sls_quantity,0)
   else sls_price
end as sls_price,
from bronze.crm_sales_details
where sls_Sales != sls_quantity*sls_price
or sls_sales is null or sls_quantity is null or sls_price is null
or sls_sales <=0 or sls_quantity<=0 or sls_price<=0


--=======================================================================
--checking 'silver.crp_cust_az12'
--=========================================================================

select * from bronze.erp_cust_az12;

select * from silver.crm_cust_info;
--------
select 
case when cid like 'NAS%' then substring(cid,4,len(cid))
     else cid
end cid,
case when bdate>getdate() then null
     else bdate
end as bdate,
case when trim(upper(gen)) in ('F','Female') then 'Female'
     when trim(upper(gen)) in ('M','Male') then 'Male'
     else 'n/a'
end as gen
from bronze.erp_cust_az12;


--------------------------
select distinct
bdate
from  bronze.erp_cust_az12
where bdate<'1924-01-01' or bdate>getdate()
---
select distinct 
gen,
case when trim(upper(gen)) in ('F','Female') then 'Female'
     when trim(upper(gen)) in ('M','Male') then 'Male'
     else 'n/a'
end as gen
from bronze.erp_cust_az12;



--=======================================================================
--checking 'silver.erp_loc_a101'
--=========================================================================
select
replace(cid,'-','') as cid,
case when trim(cntry) in ('USA','US') then 'United States'
     when trim(cntry)='DE' then 'Germany'
     when trim(cntry)=' ' or cntry is null then 'n/a'
     else trim(cntry)
end as cntry
from bronze.erp_loc_a101;
------------
select distinct cntry
case when trim(cntry) in ('USA','US') then 'United States'
     when trim(cntry)='DE' then 'Germany'
     when trim(cntry)=' ' or cntry is null then 'n/a'
     else trim(cntry)
end as cntry
from bronze.erp_loc_a101

-------------
select 
replace(cid,'-','')cid
from bronze.erp_loc_a101

--=======================================================================
--checking 'silver.erp_px_cat_g1v2'
--=========================================================================

select id,
cat,
subcat,
maintenance
from bronze.erp_px_cat_g1v2;

---
select * from bronze.erp_px_cat_g1v2
where cat !=Trim(cat) or subcat !=Trim(subcat) or maintenance !=Trim(maintenance)
---------
select distinct 
cat
from bronze.erp_px_cat_g1v2;

select distinct 
maintenance 
from bronze.erp_px_cat_g1v2;
