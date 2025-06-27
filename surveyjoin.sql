CREATE TABLE SURVEY (
    survey_id TEXT PRIMARY KEY,
    survey_name TEXT NOT NULL,
    region TEXT NOT NULL,
    start_date DATE NOT NULL,
    latest_date DATE
);

CREATE TABLE SPECIES (
    species_id INT PRIMARY KEY,
    itis INT,
    common_name TEXT,
    scientific_name TEXT
);

CREATE TABLE HAUL (
    event_id BIGINT PRIMARY KEY,
    survey_id TEXT NOT NULL,
    date DATE NOT NULL,
    pass SMALLINT,
    vessel TEXT,
    lat_start NUMERIC(9, 6),
    lon_start NUMERIC(9, 6),
    lat_end NUMERIC(9, 6),
    lon_end NUMERIC(9, 6),
    depth_m NUMERIC(8, 4),
    effort NUMERIC(12, 11),
    effort_units CHAR(3),
    performance TEXT,
    stratum SMALLINT,
    bottom_temp_c NUMERIC(7, 5),

    CONSTRAINT fk_survey
        FOREIGN KEY (survey_id)
        REFERENCES SURVEY (survey_id)
        ON UPDATE CASCADE
);

CREATE TABLE CATCH (
    catch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    survey_id TEXT NOT NULL,
    event_id BIGINT NOT NULL,
    species_id INT,
    catch_numbers INT,
    catch_weight NUMERIC(8, 3),

    CONSTRAINT fk_haul
        FOREIGN KEY (event_id)
        REFERENCES HAUL (event_id),

    CONSTRAINT fk_species
        FOREIGN KEY (species_id)
        REFERENCES SPECIES (species_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

	CONSTRAINT fk_catch_survey
        FOREIGN KEY (survey_id)
        REFERENCES SURVEY (survey_id)
        ON UPDATE CASCADE
);
