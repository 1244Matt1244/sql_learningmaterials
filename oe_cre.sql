rem
rem Header: oe_cre.sql 09-jan-01
rem
rem Copyright (c) 2001 Oracle Corporation.  All rights reserved.
rem
rem Owner  : ahunold
rem
rem NAME
rem   oe_cre.sql - create OE Common Schema
rem
rem DESCRIPTON
rem   Creates database objects. 
rem
rem NOTES
rem   The OIDs assigned for the object types are used to 
rem   simplify the setup of Replication demos and are not needed
rem   in most unreplicated environments.
rem
rem MODIFIED   (MM/DD/YY)
rem   ahunold   11/15/01 - changes specific for cloned schemas
rem   ahunold   04/25/01 - OID
rem   ahunold   03/02/01 - eliminating DROP SEQUENCE
rem   ahunold   01/30/01 - OE script headers
rem   ahunold   01/24/01 - Eliminate extra lines from last merge
rem   ahunold   01/05/01 - promo_id
rem   ahunold   01/05/01 - NN constraints in product_descriptions
rem   ahunold   01/09/01 - checkin ADE

rem SPOOL oe_cre.out

REM ===========================================================================
REM Create customers table.
REM ===========================================================================

CREATE TABLE customers
    ( customer_id        NUMBER(6)     
    , cust_first_name    VARCHAR2(20) CONSTRAINT cust_fname_nn NOT NULL
    , cust_last_name     VARCHAR2(20) CONSTRAINT cust_lname_nn NOT NULL
    , address	         VARCHAR2(30)
    , postal_code        VARCHAR2(30)
    , city	         VARCHAR2(30)
    , state	         VARCHAR2(30)
    , country	         VARCHAR2(30)
    , phone_number       VARCHAR2(30)
    , nls_language       VARCHAR2(3)
    , nls_territory      VARCHAR2(30)
    , credit_limit       NUMBER(9,2)
    , cust_email         VARCHAR2(30)
    , account_mgr_id     NUMBER(6)
    , status      	 VARCHAR2(30)
    , CONSTRAINT         customer_credit_limit_max
                         CHECK (credit_limit <= 750000)
    , CONSTRAINT         customer_id_min
                         CHECK (customer_id > 0)
    ) ;

CREATE UNIQUE INDEX customers_pk
   ON customers (customer_id) ;
   
REM Both table and indexes are analyzed using the oe_analz.sql script.

ALTER TABLE customers 
ADD ( CONSTRAINT customers_pk
      PRIMARY KEY (customer_id)
    ) ;

REM ===========================================================================
REM Create warehouses table; 
REM  includes spatial data column wh_geo_location and
REM  XML type warehouse_spec (was bug b41)
REM ===========================================================================

CREATE TABLE warehouses
    ( warehouse_id       NUMBER(3) 
    , warehouse_name     VARCHAR2(35)
    , location_id        NUMBER(4)
    ) ;

CREATE UNIQUE INDEX warehouses_pk
ON warehouses (warehouse_id) ;

ALTER TABLE warehouses 
ADD (CONSTRAINT warehouses_pk PRIMARY KEY (warehouse_id)
    );

REM ===========================================================================
REM Create table order_items.
REM ===========================================================================
	
CREATE TABLE order_items
    ( order_id           NUMBER(12) 
    , line_item_id       NUMBER(3)  NOT NULL
    , product_id         NUMBER(6)  NOT NULL
    , unit_price         NUMBER(8,2)
    , discount_price     NUMBER(8,2)
    , quantity           NUMBER(8)
    ) ;

CREATE UNIQUE INDEX order_items_pk
ON order_items (order_id, line_item_id) ;

CREATE UNIQUE INDEX order_items_uk
ON order_items (order_id, product_id) ;

ALTER TABLE order_items
ADD ( CONSTRAINT order_items_pk PRIMARY KEY (order_id, line_item_id)
    );

CREATE OR REPLACE TRIGGER insert_ord_line
  BEFORE INSERT ON order_items
  FOR EACH ROW 
  DECLARE 
    new_line number; 
  BEGIN 
    SELECT (NVL(MAX(line_item_id),0)+1) INTO new_line 
      FROM order_items
      WHERE order_id = :new.order_id; 
    :new.line_item_id := new_line; 
  END; 
/

REM ===========================================================================
REM Create table orders, which includes a TIMESTAMP column and a check
REM constraint.
REM ===========================================================================

CREATE TABLE orders
    ( order_id           NUMBER(12)
    , order_date         DATE
CONSTRAINT order_date_nn NOT NULL
    , order_mode         VARCHAR2(8)
    , customer_id        NUMBER(6) CONSTRAINT order_customer_id_nn NOT NULL
    , order_status       NUMBER(2)
    , order_total        NUMBER(8,2)
    , sales_rep_id       NUMBER(6)
    , promotion_id       NUMBER(6)
    , CONSTRAINT         order_mode_lov
                         CHECK (order_mode in ('direct','online'))
    , constraint         order_total_min
                         check (order_total >= 0)
    ) ;

CREATE UNIQUE INDEX order_pk 
ON orders (order_id) ;

ALTER TABLE orders
ADD ( CONSTRAINT order_pk 
      PRIMARY KEY (order_id)
    );
REM ===========================================================================
REM Create inventories table, which contains a concatenated primary key.
REM ===========================================================================
    
CREATE TABLE inventories
  ( product_id         NUMBER(6)
  , warehouse_id       NUMBER(3) CONSTRAINT inventory_warehouse_id_nn NOT NULL
  , quantity_on_hand   NUMBER(8)
CONSTRAINT inventory_qoh_nn NOT NULL
  , CONSTRAINT inventory_pk PRIMARY KEY (product_id, warehouse_id)
  ) ;

REM ===========================================================================
REM Create categories table.
REM ===========================================================================


CREATE TABLE categories
    ( category_name           VARCHAR2(50) 
    , category_description    VARCHAR2(1000) 
    , category_id             NUMBER(2) 
CONSTRAINT category_qoh_nn NOT NULL
  , CONSTRAINT category_pk PRIMARY KEY (category_id)
      ) ;
   
REM ===========================================================================
REM Create table product_information, which contains an INTERVAL datatype and
REM a CHECK ... IN constraint.
REM ===========================================================================

CREATE TABLE product_information
    ( product_id          NUMBER(6)
    , product_name        VARCHAR2(50)
    , product_description VARCHAR2(2000)
    , category_id         NUMBER(2)
    , weight_class        NUMBER(1)
    , supplier_id         NUMBER(6)
    , product_status      VARCHAR2(20)
    , list_price          NUMBER(8,2)
    , min_price           NUMBER(8,2)
    , catalog_url         VARCHAR2(50)
    , CONSTRAINT          product_status_lov
                          CHECK (product_status in ('orderable'
                                                  ,'planned'
                                                  ,'under development'
                                                  ,'obsolete')
                               )
    ) ;

ALTER TABLE product_information 
ADD ( CONSTRAINT product_information_pk PRIMARY KEY (product_id)
    );

REM ===========================================================================
REM Create table product_descriptions, which contains NVARCHAR2 columns for
REM NLS-language information.
REM ===========================================================================

CREATE TABLE product_descriptions
    ( product_id             NUMBER(6)
    , language_id            VARCHAR2(3)
    , translated_name        NVARCHAR2(50)
CONSTRAINT translated_name_nn NOT NULL
    , translated_description NVARCHAR2(2000)
CONSTRAINT translated_desc_nn NOT NULL
    );

CREATE UNIQUE INDEX prd_desc_pk
ON product_descriptions(product_id,language_id) ;

ALTER TABLE product_descriptions
ADD ( CONSTRAINT product_descriptions_pk 
	PRIMARY KEY (product_id, language_id));

ALTER TABLE orders 
ADD ( CONSTRAINT orders_sales_rep_fk 
      FOREIGN KEY (sales_rep_id) 
      REFERENCES employees(employee_id)
      ON DELETE SET NULL
    ) ;

ALTER TABLE orders 
ADD ( CONSTRAINT orders_customer_id_fk 
      FOREIGN KEY (customer_id) 
      REFERENCES customers(customer_id) 
      ON DELETE SET NULL 
    ) ;

ALTER TABLE warehouses 
ADD ( CONSTRAINT warehouses_location_fk 
      FOREIGN KEY (location_id)
      REFERENCES locations(location_id)
      ON DELETE SET NULL
    ) ;

ALTER TABLE customers
ADD ( CONSTRAINT customers_account_manager_fk
      FOREIGN KEY (account_mgr_id)
      REFERENCES employees(employee_id)
      ON DELETE SET NULL
    ) ;

ALTER TABLE inventories 
ADD ( CONSTRAINT inventories_warehouses_fk 
      FOREIGN KEY (warehouse_id)
      REFERENCES warehouses (warehouse_id)
      ENABLE NOVALIDATE
    ) ;

ALTER TABLE inventories 
ADD ( CONSTRAINT inventories_product_id_fk 
      FOREIGN KEY (product_id)
      REFERENCES product_information (product_id)
    ) ;

ALTER TABLE order_items
ADD ( CONSTRAINT order_items_order_id_fk 
      FOREIGN KEY (order_id)
      REFERENCES orders(order_id)
      ON DELETE CASCADE
enable novalidate
    ) ;

ALTER TABLE order_items
ADD ( CONSTRAINT order_items_product_id_fk 
      FOREIGN KEY (product_id)
      REFERENCES product_information(product_id)
    ) ;

ALTER TABLE product_information
ADD ( CONSTRAINT prod_info_category_id_fk 
      FOREIGN KEY (category_id)
      REFERENCES categories(category_id)
    ) ;

REM ===========================================================================
REM Create sequences
REM ===========================================================================

CREATE SEQUENCE orders_seq
 START WITH     1000
 INCREMENT BY   1
 NOCACHE
 NOCYCLE;

REM ===========================================================================
REM Need commit for PO
REM ===========================================================================

COMMIT;


rem exit;
