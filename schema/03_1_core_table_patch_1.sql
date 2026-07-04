-- add hierarchy_level to roles

ALTER TABLE core.roles ADD hierarchy_level INT NOT NULL DEFAULT 0;

/*

customer          → level 1
restaurant_staff   → level 2
branch_owner        → level 3
brand_owner          → level 3
driver                → level 2
admin                  → level 5
super_admin             → level 10

*/