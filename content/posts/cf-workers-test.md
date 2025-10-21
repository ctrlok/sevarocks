+++
title = "Тестування Rust Cloudflare Workers"
date = "2025-10-20"
description = "Як тестувати cloudflare workers написані на Rust"
[extra]
og_image = "https://static.seva.rocks/images/rustcrab.jpg"
+++

Одна з причин чому не люблю усіляку логіку в конфігах балансера це складність тестування змін. Тому пишу крізь сльози щастя: можу створювати роутери на справжній мові під cloudflare workers.

Очевидно[^1] що в якості мови я обрав Rust. 

[^1]: Добре, неочевидно. Та і я не одразу обрав Rust. Спроби швиденько пописати на JS були. Але помилки супер незрозумілі, нема типів і ітераторів, це що, 2002 рік на дворі? Можна було б обрати тайпскрипт, але я його зовсім не знаю, тому і раст. 


## Тестування fetch()

Перше що приходить на думку (і майже завжди правильно) це просто смикати усього воркера і дивитись що воно віддає. 

Наприклад у нас є такий собі воркер:
```rust
use worker::*;

#[event(fetch)]
async fn fetch(req: Request, env: Env, ctx: Context) -> Result<Response> {
    if let Some(cf) = req.cf()
        && let Some(country) = cf.country()
        && (country == "RU" || country == "BY")
    {
        return Response::error("Access denied. Guess why?", 403);
    }
    Response::ok("Hello World!")
}
```

Можемо написати дуже простий код на [тайпскрипт + vitest](https://developers.cloudflare.com/workers/testing/vitest-integration/):

```ts
import { describe, it, expect } from "vitest";
import { env, SELF } from "cloudflare:test";

describe("Worker", () => {
  it("should block requests from (RU) with 403", async () => {
    const request = new Request("http://example.com", {
      cf: {
        country: "RU",
      },
    });
    const resp = await SELF.fetch(request);
    expect(resp.status).toBe(403);
    expect(await resp.text()).toBe("Access denied");
  });

  it("should block requests from (BY) with 403", async () => {
    const request = new Request("http://example.com", {
      cf: {
        country: "BY",
      },
    });
    const resp = await SELF.fetch(request);
    expect(resp.status).toBe(403);
    expect(await resp.text()).toBe("Access denied");
  });

  it("should allow requests from other countries with 200", async () => {
    const request = new Request("http://example.com", {
      cf: {
        country: "US",
      },
    });
    const resp = await SELF.fetch(request);
    expect(resp.status).toBe(200);
    expect(await resp.text()).toBe("Hello World!");
  });

  it("should allow requests without country info with 200", async () => {
    const request = new Request("http://example.com");
    const resp = await SELF.fetch(request);
    expect(resp.status).toBe(200);
    expect(await resp.text()).toBe("Hello World!");
  });
});

```
І запустити цей код за допомогою `pnpm test`
#### Що тільки що відбулося?

Cloudflare workers це V8 [^2], який запускає джаваскріпт код. Якщо ми використовуємо vitest з лібою cloudflare:test то воно вміє запускати двіжок воркерів, який потім запускає збілджений раст код і ми просто смикаємо фетчапі(в утці заєць, а в зайці голка).

[^2]: [Ось тут більше деталей](https://developers.cloudflare.com/workers/reference/how-workers-works/) про ізоляцію і взагалі про те що відбувається.


## Інтеграційні тести

Для простих сценаріїв такого має бути взагалі достатньо. Але ми ж не шукаємо простих шляхів. Наша доля складна і буремна, нам потрібні виклики. Наприклад, виклики бази данних. 

> [!IMPORTANT] 
> *Важливо:* далі функції мають виключно демонстраційний і спрощений характер. Це зроблено задля того щоб ви не відволікались на складність самої логіки, а дивились на демонтрацію механіки. 

Давай уявимо що у нас є код який рахує скільки разів користувач смикнув воркер і далі виконує якусь логіку на цьому:

```rust
use worker::*;

#[event(fetch)]
async fn fetch(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    let user_id = get_user_id(&req);
    let db = env.d1("DB")?;
    let request_count = number_of_requests(db, user_id).await?;
    logic_based_on_request_count(request_count, req)
}

async fn number_of_requests(db: D1Database, user_id: i32) -> Result<i32> {
    let statement = db.prepare(
        "INSERT INTO user_requests (user_id, count, last_updated)
         VALUES (?1, 1, CURRENT_TIMESTAMP)
         ON CONFLICT(user_id)
         DO UPDATE SET count = user_requests.count + 1, last_updated = CURRENT_TIMESTAMP
         RETURNING count",
    );

    let count = statement
        .bind(&[user_id.into()])?
        .first::<i32>(Some("count"))
        .await?
        .unwrap_or(0); // Вертаємо 0, якщо щось пішло не так
    Ok(count)
}

fn get_user_id(_: &Request) -> i32 {
    42 // Плейсходер, в майбутньому можна отримувати з аутентифікації
}

fn logic_based_on_request_count(count: i32, req: Request) -> Result<Response> {
    todo!()
}
```

Це вже складніше тестувати з fetch(), тому що далі логіка може бути досить складною, а кожена варіація збільшує кількість сценаріїв тестування [^3]

[^3]: Наприклад, у нас є метод fetch() який послідовно викликає функції A, B, C і використовує результати однієї функції як аргументи до наступної. 
	
	Тоді, 
	```
	A = {a₁, a₂, a₃, a₄}  // 4 можливі стани функції 
	B = {b₁, b₂, b₃}      // 3 можливі стани функції B
	C = {c₁, c₂, c₃}      // 3 можливі стани функції C

	A × B × C = {(aᵢ, bⱼ, cₖ) | aᵢ ∈ A, bⱼ ∈ B, cₖ ∈ C}
	|A × B × C| = |A| × |B| × |C| = 4 × 3 × 3 = 36 комбінацій
	```
	В той самий час як індивідуальне тестування кожної функції принесе всього 10 комбінацій. Це набагато менше ніж 36. 
	
	І так, я розумію що в реальному світі буде менш ніж 36 комбінацій, але точно більше ніж 10. 

Тому має більший сенс тестувати кожну функцію окремо. 

## wasm_bindgen

Для того щоб передати об’єкт бази данних до функції `number_of_requests()` треба спочатку згенерети біндінги [^4]

[^4]: Уяви, що в тебе є два друга які спілкуються різними мовами. Rust каже "я контролюю пам'ять", а JavaScript каже "я взагалі не знаю що таке пам'ять, але у мене є undefined". І от вони хочуть разом щось зробити. Біндінги — це той перекладач, який сидить між ними і перекладає їхні божевільні розмови. Хоча я б таких друзів в дурку здав. І залишився б без друзів. 

Для цього можна використати існуючі макроси з `wasm_bindgen`. Тоді для такої функції: 

```rust 
#[wasm_bindgen]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

За допомогою команди `worker-build --release` будуть згенеровані біндінги в typescript і javascript:

```typescript
/* tslint:disable */
/* eslint-disable */
export function fetch(req: Request, env: any, ctx: any): Promise<Response>;
export function add(a: number, b: number): number;
export function setPanicHook(callback: Function): void;
...
```

### Складні об’єкти

Але наша функція `async fn number_of_requests(db: D1Database, user_id: i32) -> Result<i32>` приймає базу данних як вхідний параметр. І якщо ми додамо макрос `#[wasm_bindgen] то отримаємо помилку 

{% wide() %}
```
the trait bound `worker::D1Database: worker::wasm_bindgen::convert::FromWasmAbi` is not satisfied [E0277]
Help: the following other types implement trait `worker::wasm_bindgen::convert::FromWasmAbi`:
```
{% end %}
Це значить що нам треба зробити функцію обгортку

```rust
// #[cfg(debug_assertions)] Для того щоб генерувати обгортку лише 
// в режимі тестування
#[cfg(debug_assertions)]
use wasm_bindgen::prelude::*;

#[cfg(debug_assertions)]
#[wasm_bindgen]
pub async fn wrap_number_of_requests(db: JsValue, user_id: i32) -> Result<i32> {
    let db: D1Database = db.unchecked_into();
    number_of_requests(db, user_id).await
}
```

Тобто ми точно очікуємо лише базу данних, тому на вхід отримуємо якийсь об’єкт, який потім конвертуємо в базу данних [^5].

[^5]: можливо і потрібно створювати біндінги і під об’єкти у вашому раст коді. 
	Наприклад
	```rust
	#[cfg(debug_assertions)]
	use serde::{Deserialize, Serialize};
	#[cfg(debug_assertions)]
	use wasm_bindgen::prelude::*;

	#[cfg(debug_assertions)]
	#[derive(Serialize, Deserialize)]
	pub struct RequestCountResult {
	    pub success: bool,
	    pub count: i32,
	    pub error_message: String,
	}
	``` 
	
	Тепер ця структура доступна і з тайпскрипту. 

Завдяки цьому тепер ми можемо написати тести


```typescript
import {env} from 'cloudflare:test';
import {afterEach, beforeAll, describe, expect, it} from 'vitest';
import init, {wrap_number_of_requests} from './pkg/cftest.js'; // шлях до біндінгів
import wasm from './pkg/cftest_bg.wasm'; // шлях до WASM файлу

describe('wrap_number_of_requests - integration tests', () => {
    // Беремо нашу базу данних
    const db = env.DB;

    beforeAll(async () => {
        await init(wasm);
    });

    afterEach(async () => {
        await db.prepare('DELETE FROM user_requests').run();
    });

    it('should return count 1 for first request', async () => {
        const result = await wrap_number_of_requests(db, 42);
        expect(result).toBe(1);
    });

    it('should increment count with each call', async () => {
        const result1 = await wrap_number_of_requests(db, 42);
        expect(result1).toBe(1);

        const result2 = await wrap_number_of_requests(db, 42);
        expect(result2).toBe(2);

        const result3 = await wrap_number_of_requests(db, 42);
        expect(result3).toBe(3);
    });

    it('should track different users separately', async () => {
        // User 42
        const result1 = await wrap_number_of_requests(db, 42);
        expect(result1).toBe(1);

        // User 100
        const result2 = await wrap_number_of_requests(db, 100);
        expect(result2).toBe(1);

        // User 42 again
        const result3 = await wrap_number_of_requests(db, 42);
        expect(result3).toBe(2);

        // User 100 again
        const result4 = await wrap_number_of_requests(db, 100);
        expect(result4).toBe(2);
    });

    describe('error handling', () => {
        it('should throw error when table does not exist', async () => {
            await db.prepare('DROP TABLE IF EXISTS user_requests').run();
            await expect(wrap_number_of_requests(db, 42)).rejects.toThrow();
        });

        it('should throw error when schema has wrong structure', async () => {
            await db.prepare('DROP TABLE IF EXISTS user_requests').run();
            await db.prepare(`
                CREATE TABLE user_requests (
                    user_id INTEGER PRIMARY KEY,
                    wrong_column TEXT
                )
            `).run();
            await expect(wrap_number_of_requests(db, 42)).rejects.toThrow();
        });
    });
});
```

Треба тільки не забувати перед кожним запуском тестів білдити код і генерувати біндінги:

```bash
# якщо наш код тестів в ./test/, то 
wasm-pack build --dev --target web --out-dir test/pkg
pnpm test
```

Я просто запхав усе необхідне в Justfile, але хто як любить. 

Сподіваюсь тепер писати на расті під воркери буде простіше. Та і vitest тести мені дуже сподобались, може і вам зайде. 

{{ tg(id="UkropsDigest/704")}}
