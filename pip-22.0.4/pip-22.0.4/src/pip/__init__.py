from typing import List, Optional

__version__ = "22.0.4"


def main(args: Optional[List[str]] = None) -> int:

    from pip._internal.utils.entrypoints import _wrapper

    return _wrapper(args)
