import type { MaybePromise } from '../catalog/catalog.contract.js';
import type {
  CreateUserInput,
  UpdateUserInput,
  UserView,
} from './users.service.js';

export interface UsersServiceContract {
  listUsers(companyId: string): MaybePromise<UserView[]>;
  createUser(input: CreateUserInput): MaybePromise<UserView>;
  updateUser(input: UpdateUserInput): MaybePromise<UserView>;
}
