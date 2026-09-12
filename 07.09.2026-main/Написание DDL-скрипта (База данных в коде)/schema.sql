-- ============================================================
-- schema.sql — DDL-скрипт для развертывания базы данных
-- Диалект: MySQL / MariaDB
--
-- Сущности:
--   partners       — партнёры
--   products       — товары
--   deliveries     — отгрузки партнёрам
--   delivery_items — позиции отгрузок
--
-- Соглашение об именовании:
--   таблицы и столбцы именуются в snake_case;
--   названия таблиц используются во множественном числе.
-- ============================================================


-- ============================================================
-- ЧАСТЬ 1. УДАЛЕНИЕ ТАБЛИЦ
-- Сначала удаляются дочерние таблицы, затем родительские.
-- ============================================================

DROP TABLE IF EXISTS delivery_items;
DROP TABLE IF EXISTS deliveries;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS partners;


-- ============================================================
-- ЧАСТЬ 2. СОЗДАНИЕ ТАБЛИЦ
-- Сначала создаются родительские таблицы, затем дочерние.
-- ============================================================


-- ============================================================
-- Таблица partners
-- Содержит основные сведения о партнёрах.
-- ============================================================

CREATE TABLE partners (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    inn             VARCHAR(12)     NOT NULL,
    company_name    VARCHAR(255)    NOT NULL,
    contact_person  VARCHAR(255)    DEFAULT NULL,
    email           VARCHAR(255)    NOT NULL,
    phone           VARCHAR(20)     DEFAULT NULL,
    address         VARCHAR(500)    DEFAULT NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                           ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_partners
        PRIMARY KEY (id),

    CONSTRAINT uq_partners_inn
        UNIQUE (inn),

    CONSTRAINT uq_partners_email
        UNIQUE (email),

    CONSTRAINT chk_partners_inn
        CHECK (CHAR_LENGTH(inn) IN (10, 12)),

    CONSTRAINT chk_partners_company_name
        CHECK (CHAR_LENGTH(TRIM(company_name)) > 0),

    CONSTRAINT chk_partners_email
        CHECK (CHAR_LENGTH(TRIM(email)) > 0)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Партнёры организации';


-- ============================================================
-- Таблица products
-- Содержит каталог товаров.
-- Текущая цена хранится в products, а фактическая цена
-- конкретной отгрузки — в delivery_items.
-- ============================================================

CREATE TABLE products (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    sku             VARCHAR(50)     NOT NULL,
    product_name    VARCHAR(255)    NOT NULL,
    description     TEXT            DEFAULT NULL,
    current_price   DECIMAL(12, 2)  NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                           ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_products
        PRIMARY KEY (id),

    CONSTRAINT uq_products_sku
        UNIQUE (sku),

    CONSTRAINT chk_products_name
        CHECK (CHAR_LENGTH(TRIM(product_name)) > 0),

    CONSTRAINT chk_products_current_price
        CHECK (current_price >= 0)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Каталог товаров';


-- ============================================================
-- Таблица deliveries
-- Содержит заголовки отгрузок.
-- Каждая отгрузка принадлежит одному партнёру.
-- ============================================================

CREATE TABLE deliveries (
    id                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    delivery_number     VARCHAR(50)     NOT NULL,
    partner_id          INT UNSIGNED    NOT NULL,
    delivery_date       DATE            NOT NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'planned',
    delivery_address    VARCHAR(500)    DEFAULT NULL,
    comment             TEXT            DEFAULT NULL,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                               ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_deliveries
        PRIMARY KEY (id),

    CONSTRAINT uq_deliveries_number
        UNIQUE (delivery_number),

    CONSTRAINT fk_deliveries_partner
        FOREIGN KEY (partner_id)
        REFERENCES partners (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_deliveries_number
        CHECK (CHAR_LENGTH(TRIM(delivery_number)) > 0),

    CONSTRAINT chk_deliveries_status
        CHECK (
            status IN (
                'planned',
                'shipped',
                'delivered',
                'cancelled'
            )
        )
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'История отгрузок партнёрам';


-- ============================================================
-- Таблица delivery_items
-- Содержит товарные позиции каждой отгрузки.
--
-- unit_price фиксирует цену товара на момент отгрузки.
-- Итоговая стоимость позиции вычисляется как:
-- quantity * unit_price.
--
-- Полная сумма отгрузки не хранится, поскольку является
-- вычисляемым значением.
-- ============================================================

CREATE TABLE delivery_items (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    delivery_id     INT UNSIGNED    NOT NULL,
    product_id      INT UNSIGNED    NOT NULL,
    quantity        INT UNSIGNED    NOT NULL,
    unit_price      DECIMAL(12, 2)  NOT NULL,

    CONSTRAINT pk_delivery_items
        PRIMARY KEY (id),

    CONSTRAINT uq_delivery_items_delivery_product
        UNIQUE (delivery_id, product_id),

    CONSTRAINT fk_delivery_items_delivery
        FOREIGN KEY (delivery_id)
        REFERENCES deliveries (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_delivery_items_product
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_delivery_items_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_delivery_items_unit_price
        CHECK (unit_price >= 0)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_unicode_ci
COMMENT = 'Товарные позиции отгрузок';


-- ============================================================
-- ЧАСТЬ 3. ДОПОЛНИТЕЛЬНЫЕ ИНДЕКСЫ
-- Индексы ускоряют получение истории отгрузок партнёра,
-- поиск отгрузок по дате и соединение таблиц.
-- ============================================================

CREATE INDEX idx_deliveries_partner_date
    ON deliveries (partner_id, delivery_date);

CREATE INDEX idx_deliveries_date
    ON deliveries (delivery_date);

CREATE INDEX idx_deliveries_status
    ON deliveries (status);

CREATE INDEX idx_delivery_items_product
    ON delivery_items (product_id);