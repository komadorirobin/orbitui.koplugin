import datetime
from pathlib import Path
import re
import sqlite3
import unittest


class MonthlyActivitySQLTest(unittest.TestCase):
    def test_distinct_pages_per_book_per_day_and_empty_year_sentinel(self):
        source = (Path(__file__).resolve().parents[1] /
                  "components/simpleui/modules/module_stats_provider.lua").read_text()
        section = source.split("local function fetchYearPages(conn, year)", 1)[1]
        query = re.search(r"conn:exec\(string.format\(\[\[(.*?)\]\]", section, re.S)[1]
        stamp = lambda month, day: int(datetime.datetime(2026, month, day, 12).timestamp())
        db = sqlite3.connect(":memory:")
        db.execute("CREATE TABLE page_stat_data (start_time, page, id_book, duration)")
        db.executemany("INSERT INTO page_stat_data VALUES (?, ?, ?, ?)", [
            (stamp(1, 2), 1, 1, 10), (stamp(1, 2), 1, 1, 15),
            (stamp(1, 2), 1, 2, 10), (stamp(1, 3), 1, 1, 10),
            (stamp(1, 3), 2, 1, 0), (stamp(10, 5), 8, 1, 5)])
        start = lambda year: int(datetime.datetime(year, 1, 1).timestamp())
        self.assertEqual(db.execute(query % (start(2026), start(2027))).fetchall(),
                         [("01", 3), ("10", 1), (0, 0)])
        self.assertEqual(db.execute(query % (start(2027), start(2028))).fetchall(), [(0, 0)])
        db.close()


if __name__ == "__main__":
    unittest.main()
