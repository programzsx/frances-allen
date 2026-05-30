import time
import threading


class SnowflakeGenerator:
    """雪花ID生成器 - 64位整数唯一ID"""

    def __init__(self, worker_id: int = 1, datacenter_id: int = 1):
        self.worker_id = worker_id
        self.datacenter_id = datacenter_id
        self.sequence = 0
        self.last_timestamp = -1
        self._lock = threading.Lock()

        # 位分配
        self.worker_id_bits = 5
        self.datacenter_id_bits = 5
        self.sequence_bits = 12

        self.max_worker_id = -1 ^ (-1 << self.worker_id_bits)
        self.max_datacenter_id = -1 ^ (-1 << self.datacenter_id_bits)
        self.max_sequence = -1 ^ (-1 << self.sequence_bits)

        # 位移
        self.worker_id_shift = self.sequence_bits
        self.datacenter_id_shift = self.sequence_bits + self.worker_id_bits
        self.timestamp_shift = (
            self.sequence_bits + self.worker_id_bits + self.datacenter_id_bits
        )

        # 自定义纪元: 2024-01-01
        self.custom_epoch = 1704067200000

        if self.worker_id > self.max_worker_id or self.worker_id < 0:
            raise ValueError(f"worker_id must be 0~{self.max_worker_id}")
        if self.datacenter_id > self.max_datacenter_id or self.datacenter_id < 0:
            raise ValueError(f"datacenter_id must be 0~{self.max_datacenter_id}")

    def _current_millis(self) -> int:
        return int(time.time() * 1000)

    def _wait_next_millis(self, last_timestamp: int) -> int:
        timestamp = self._current_millis()
        while timestamp <= last_timestamp:
            timestamp = self._current_millis()
        return timestamp

    def generate_id(self) -> str:
        with self._lock:
            timestamp = self._current_millis()

            if timestamp < self.last_timestamp:
                raise RuntimeError("Clock moved backwards")

            if timestamp == self.last_timestamp:
                self.sequence = (self.sequence + 1) & self.max_sequence
                if self.sequence == 0:
                    timestamp = self._wait_next_millis(self.last_timestamp)
            else:
                self.sequence = 0

            self.last_timestamp = timestamp

            snowflake_id = (
                ((timestamp - self.custom_epoch) << self.timestamp_shift)
                | (self.datacenter_id << self.datacenter_id_shift)
                | (self.worker_id << self.worker_id_shift)
                | self.sequence
            )

            return str(snowflake_id)


snowflake = SnowflakeGenerator()
