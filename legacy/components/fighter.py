from __future__ import annotations

from typing import TYPE_CHECKING

import color
from components.base_component import BaseComponent
from render_order import RenderOrder

if TYPE_CHECKING:
    from entity import Actor


import tcod.event
import setup_game

class WaitForRestart(tcod.event.EventDispatch):
    def __init__(self, engine):
        self.engine = engine
    
    def ev_keydown(self, event: tcod.event.KeyDown) -> None:
        if event.sym == tcod.event.K_r:  # Press Enter to restart
            new_engine = setup_game.new_game()
            self.engine.__dict__.update(new_engine.__dict__)


class Fighter(BaseComponent):
    parent: Actor

    def __init__(self, hp: int, base_defense: int, base_power: int):
        self.max_hp = hp
        self._hp = hp
        self.base_defense = base_defense
        self.base_power = base_power

    @property
    def hp(self) -> int:
        return self._hp

    @hp.setter
    def hp(self, value: int) -> None:
        self._hp = max(0, min(value, self.max_hp))
        if self._hp == 0 and self.parent.ai:
            self.die()

    @property
    def defense(self) -> int:
        return self.base_defense + self.defense_bonus

    @property
    def power(self) -> int:
        return self.base_power + self.power_bonus

    @property
    def defense_bonus(self) -> int:
        if self.parent.equipment:
            return self.parent.equipment.defense_bonus
        else:
            return 0

    @property
    def power_bonus(self) -> int:
        if self.parent.equipment:
            return self.parent.equipment.power_bonus
        else:
            return 0

    # def die(self) -> None:
    #     if self.engine.player is self.parent:
    #         death_message = "You died!"
    #         death_message_color = color.player_die

    #         import tcod.event
    #         import setup_game
    #         new_engine = setup_game.new_game()
    #         self.engine.__dict__.update(new_engine.__dict__)
    #     else:
    #         death_message = f"{self.parent.name} is dead!"
    #         death_message_color = color.enemy_die

    #     self.parent.char = "%"
    #     self.parent.color = (191, 0, 0)
    #     self.parent.blocks_movement = False
    #     self.parent.ai = None
    #     self.parent.name = f"remains of {self.parent.name}"
    #     self.parent.render_order = RenderOrder.CORPSE

    #     self.engine.message_log.add_message(death_message, death_message_color)

    #     self.engine.player.level.add_xp(self.parent.level.xp_given)

    
    def die(self) -> None:
        if self.engine.player is self.parent:
            death_message = "You died! Press [R] to restart."
            death_message_color = color.player_die

            from input_handlers import GameOverEventHandler
            self.engine.event_handler = GameOverEventHandler(self.engine)
        else:
            death_message = f"{self.parent.name} is dead!"
            death_message_color = color.enemy_die


        self.engine.message_log.add_message(death_message, death_message_color)
        self.parent.char = "%"
        self.parent.color = (191, 0, 0)
        self.parent.blocks_movement = False
        self.parent.ai = None
        self.parent.name = f"remains of {self.parent.name}"
        self.parent.render_order = RenderOrder.CORPSE

        self.engine.message_log.add_message(death_message, death_message_color)
        self.engine.event_handler = WaitForRestart(self.engine)
    



    def heal(self, amount: int) -> int:
        if self.hp == self.max_hp:
            return 0

        new_hp_value = self.hp + amount

        if new_hp_value > self.max_hp:
            new_hp_value = self.max_hp

        amount_recovered = new_hp_value - self.hp

        self.hp = new_hp_value

        return amount_recovered

    def take_damage(self, amount: int) -> None:
        self.hp -= amount
