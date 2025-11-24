/*
=================================================================
Stored Procedure: Load Stlver Layer (Bronze as Silver)
=================================================================
Stript Purpose:
  This stored peocedure perfores the ETt (Extract, Transform, Load) process to
  populate the "silver" schema tables fron the "bronze" schema.
Actions Performed:
  . Truecates Silvee tables.
  . Imsarts tranifermes and cleesaed data from Bronzd into Silver tables.

Paraneterss:
  None.
  This stored erocedune does net accegt any parateters ar return any values.

Usage Example:
  EXEC silver.load_silver;
==================================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    ---- INSERTION FOR crm_cust_info
    PRINT '>> Truncating Table: silver.crm_cust_info';
    truncate table  silver.crm_cust_info;
    PRINT '>> Inserting Data Into: silver.crm_cust_info';
    insert into silver.crm_cust_info(
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_material_status,
    cst_gndr,
    cst_create_date)

    select
    cst_id,cst_key,
    trim(cst_firstname) as cst_firstname,
    trim(cst_lastname) as cst_lastname,
    case when upper(trim(cst_material_status))='S' then 'Single'
         when upper(trim(cst_material_status))='M' then 'Married'
         else 'n/a'
        end cst_material_status,--Normalize marital status values to readable format

    case when upper(trim(cst_gndr))='F' then 'Female'
         when upper(trim(cst_gndr))='M' then 'Male'
         else 'n/a'
        end cst_gndr, --Normalize gender values to readable foramt
    cst_create_date
    from(
    select *,
    row_number() over(partition by cst_id order by cst_create_date desc) as flag_last
    from bronze.crm_cust_info
    where cst_id is not null
    ) as t where flag_last=1; --select the most recent record per customer

    -----INSERTION for crm.prd_info:
    PRINT '>> Truncating Table: silver.crm_prd_info';
    truncate table silver.crm_prd_info;
    PRINT '>> Inserting Data Into: silver.crm_prd_info';
    insert into silver.crm_prd_info(
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
    )
    select
    prd_id,
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

    ---insertion ofr silver.crm_sales_details
    PRINT '>> Truncating Table: silver.crm_sales_details';
    truncate table silver.crm_sales_details;
    PRINT '>> Inserting Data Into: silver.crm_sales_details';
    insert into silver.crm_sales_details(
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
    )
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

    -------insertion ofr silver.erp_cust_az12
    PRINT '>> Truncating Table: silver.erp_cust_az12';
    truncate table silver.erp_cust_az12;
    PRINT '>> Inserting Data Into: silver.erp_cust_az12'
    insert into silver.erp_cust_az12(
    cid,
    bdate,
    gen)
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

    ---------insertion ofr silver.erp_loc-a101
    PRINT '>> Truncating Table: silver.erp_loc_a101';
    truncate table silver.erp_loc_a101;
    PRINT '>> Inserting Data Into: silver.erp_loc_a101'
    insert into silver.erp_loc_a101(
    cid,
    cntry)
    select
    replace(cid,'-','') as cid,
    case when trim(cntry) in ('USA','US') then 'United States'
         when trim(cntry)='DE' then 'Germany'
         when trim(cntry)=' ' or cntry is null then 'n/a'
         else trim(cntry)
    end as cntry
    from bronze.erp_loc_a101;

    --------------insertion ofr silver.erp_px_cat_g1v2
    PRINT '>> Truncating Table: silver.erp_px_cat_g1v2 ';
    truncate table silver.erp_px_cat_g1v2;
    PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2'
    insert into silver.erp_px_cat_g1v2(
    id,
    cat,
    subcat,
    maintenance
    )
    select id,
    cat,
    subcat,
    maintenance
    from bronze.erp_px_cat_g1v2;
END
