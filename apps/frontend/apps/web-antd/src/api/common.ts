export type ID = number | string;
export type IDS = (number | string)[];

export interface PageQuery {
  page?: number;
  size?: number;
  [key: string]: any;
}

export interface PageResult<T> {
  list: T[];
  total: number;
}
